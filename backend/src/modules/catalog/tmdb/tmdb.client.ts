import { Injectable, Logger } from '@nestjs/common';
import { tmdbConfig } from './tmdb.config';
import { TmdbConfigError, TmdbRequestError } from './tmdb.errors';

export interface TmdbMovie {
  id: number;
  title: string;
  overview: string;
  poster_path: string | null;
  release_date: string;
}

export interface TmdbPagedResponse<T> {
  page: number;
  results: T[];
  total_pages: number;
  total_results: number;
}

const RETRYABLE_STATUSES = new Set([429, 500, 502, 503, 504]);

// Thin wrapper around the TMDB REST API: adds auth, a per-request timeout,
// and retry-with-backoff for transient failures. No caching, no domain
// mapping — that's the sync job's job (BE-11), not this client's.
@Injectable()
export class TmdbClient {
  private readonly logger = new Logger(TmdbClient.name);

  getNowPlaying(page = 1): Promise<TmdbPagedResponse<TmdbMovie>> {
    return this.get<TmdbPagedResponse<TmdbMovie>>('/movie/now_playing', {
      page: String(page),
      language: 'pt-BR',
    });
  }

  // Fonte dos candidatos a "em breve" — now_playing só traz filmes já
  // lançados, então sem esta chamada nunca haveria filme com releaseDate no
  // futuro no banco.
  getUpcoming(page = 1): Promise<TmdbPagedResponse<TmdbMovie>> {
    return this.get<TmdbPagedResponse<TmdbMovie>>('/movie/upcoming', {
      page: String(page),
      language: 'pt-BR',
    });
  }

  async get<T>(path: string, params: Record<string, string> = {}): Promise<T> {
    const apiKey = tmdbConfig.apiKey;
    if (!apiKey) {
      throw new TmdbConfigError('TMDB_API_KEY não configurada');
    }

    const url = this.buildUrl(path);
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }
    // v3 API keys (a 32-char hex string) authenticate via query param; v4
    // read access tokens (a long JWT) authenticate via a Bearer header
    // instead — see request(). TMDB still supports both.
    if (!this.isV4ReadAccessToken(apiKey)) {
      url.searchParams.set('api_key', apiKey);
    }

    const totalAttempts = tmdbConfig.maxRetries + 1;
    let lastError: unknown;

    for (let attempt = 1; attempt <= totalAttempts; attempt++) {
      try {
        return await this.request<T>(url, apiKey);
      } catch (err) {
        lastError = err;
        if (attempt === totalAttempts || !this.isRetryable(err)) {
          throw err;
        }
        const delay = Math.min(
          tmdbConfig.retryBaseDelayMs * 2 ** (attempt - 1),
          5000,
        );
        this.logger.warn(
          `TMDB ${path} failed (attempt ${attempt}/${totalAttempts}), retrying in ${delay}ms: ${
            err instanceof Error ? err.message : String(err)
          }`,
        );
        await this.sleep(delay);
      }
    }

    // Unreachable — the loop always returns or throws — but keeps TS happy
    // about every code path returning/throwing.
    throw lastError;
  }

  // `new URL(path, base)` drops the base's own path segment whenever `path`
  // starts with "/" (root-relative wins over the base) — e.g.
  // new URL('/movie/x', 'https://host/3') resolves to 'https://host/movie/x',
  // silently losing the '/3'. Normalize both sides so the base path always
  // survives, regardless of whether callers write the leading slash.
  private buildUrl(path: string): URL {
    const base = tmdbConfig.baseUrl.endsWith('/')
      ? tmdbConfig.baseUrl
      : `${tmdbConfig.baseUrl}/`;
    const relativePath = path.startsWith('/') ? path.slice(1) : path;
    return new URL(relativePath, base);
  }

  private async request<T>(url: URL, apiKey: string): Promise<T> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), tmdbConfig.timeoutMs);

    const headers: Record<string, string> = { Accept: 'application/json' };
    if (this.isV4ReadAccessToken(apiKey)) {
      headers.Authorization = `Bearer ${apiKey}`;
    }

    try {
      const response = await fetch(url, {
        headers,
        signal: controller.signal,
      });

      if (!response.ok) {
        throw new TmdbRequestError(
          `TMDB respondeu ${response.status}`,
          response.status,
        );
      }

      return (await response.json()) as T;
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') {
        throw new TmdbRequestError(
          `TMDB não respondeu em ${tmdbConfig.timeoutMs}ms (timeout)`,
        );
      }
      throw err;
    } finally {
      clearTimeout(timeout);
    }
  }

  // v4 read access tokens are JWTs (three dot-separated segments, 100+
  // chars); v3 API keys are a bare 32-char hex string. Good enough to tell
  // them apart without a full JWT parse.
  private isV4ReadAccessToken(key: string): boolean {
    return key.length > 100 && key.split('.').length === 3;
  }

  private isRetryable(err: unknown): boolean {
    if (err instanceof TmdbRequestError) {
      return err.status === undefined || RETRYABLE_STATUSES.has(err.status);
    }
    // fetch throws a plain TypeError for DNS/connection-level failures.
    return err instanceof TypeError;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
