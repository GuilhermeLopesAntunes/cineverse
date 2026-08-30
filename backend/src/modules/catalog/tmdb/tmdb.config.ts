export interface TmdbConfig {
  // undefined (not a hard crash at boot) on purpose — the app must keep
  // serving everything else when TMDB isn't configured or is down; only an
  // actual TMDB call should fail. See ARQUITETURA_BACKEND.md's fallback note.
  apiKey: string | undefined;
  baseUrl: string;
  timeoutMs: number;
  maxRetries: number;
  retryBaseDelayMs: number;
}

export const tmdbConfig: TmdbConfig = {
  apiKey: process.env.TMDB_API_KEY,
  baseUrl: process.env.TMDB_BASE_URL ?? 'https://api.themoviedb.org/3',
  timeoutMs: Number(process.env.TMDB_TIMEOUT_MS ?? 5000),
  maxRetries: Number(process.env.TMDB_MAX_RETRIES ?? 3),
  retryBaseDelayMs: Number(process.env.TMDB_RETRY_BASE_MS ?? 300),
};
