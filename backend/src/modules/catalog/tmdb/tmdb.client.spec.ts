import { TmdbClient } from './tmdb.client';
import { tmdbConfig } from './tmdb.config';
import { TmdbConfigError, TmdbRequestError } from './tmdb.errors';

function jsonResponse(body: unknown, status = 200): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: () => Promise.resolve(body),
  } as Response;
}

describe('TmdbClient', () => {
  let client: TmdbClient;
  let fetchMock: jest.Mock;
  const originalApiKey = tmdbConfig.apiKey;

  beforeEach(() => {
    client = new TmdbClient();
    fetchMock = jest.fn();
    global.fetch = fetchMock;
    tmdbConfig.apiKey = 'test-tmdb-key';
  });

  afterEach(() => {
    jest.clearAllMocks();
    tmdbConfig.apiKey = originalApiKey;
  });

  it('throws without calling fetch when no API key is configured', async () => {
    tmdbConfig.apiKey = undefined;

    await expect(client.get('/movie/now_playing')).rejects.toBeInstanceOf(
      TmdbConfigError,
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('authenticates a v3 (hex) API key via the api_key query param, not a header', async () => {
    fetchMock.mockResolvedValue(jsonResponse({ page: 1, results: [] }));

    const result = await client.get('/movie/now_playing', { page: '1' });

    expect(result).toEqual({ page: 1, results: [] });
    const [url, options] = fetchMock.mock.calls[0] as [URL, RequestInit];
    expect(url.toString()).toBe(
      'https://api.themoviedb.org/3/movie/now_playing?page=1&api_key=test-tmdb-key',
    );
    expect(
      (options.headers as Record<string, string>).Authorization,
    ).toBeUndefined();
  });

  it('authenticates a v4 read access token (JWT-shaped) via a Bearer header, not the query string', async () => {
    const v4Token = `eyJhbGciOiJIUzI1NiJ9.${'a'.repeat(100)}.signature`;
    tmdbConfig.apiKey = v4Token;
    fetchMock.mockResolvedValue(jsonResponse({ page: 1, results: [] }));

    await client.get('/movie/now_playing');

    const [url, options] = fetchMock.mock.calls[0] as [URL, RequestInit];
    expect(url.searchParams.has('api_key')).toBe(false);
    expect((options.headers as Record<string, string>).Authorization).toBe(
      `Bearer ${v4Token}`,
    );
  });

  it('retries a 503 and succeeds once TMDB recovers', async () => {
    fetchMock
      .mockResolvedValueOnce(jsonResponse({}, 503))
      .mockResolvedValueOnce(jsonResponse({ ok: true }));

    const result = await client.get('/movie/now_playing');

    expect(result).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('gives up after exhausting retries on a persistent 500', async () => {
    fetchMock.mockResolvedValue(jsonResponse({}, 500));

    await expect(client.get('/movie/now_playing')).rejects.toThrow(
      TmdbRequestError,
    );
    // 1 initial attempt + tmdbConfig.maxRetries retries.
    expect(fetchMock).toHaveBeenCalledTimes(tmdbConfig.maxRetries + 1);
  });

  it('does not retry a 401 — retrying a bad credential can never succeed', async () => {
    fetchMock.mockResolvedValue(jsonResponse({}, 401));

    await expect(client.get('/movie/now_playing')).rejects.toThrow(
      TmdbRequestError,
    );
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('retries a timeout (AbortError) and gives up with a clear message', async () => {
    const abortError = new Error('The operation was aborted');
    abortError.name = 'AbortError';
    fetchMock.mockRejectedValue(abortError);

    await expect(client.get('/movie/now_playing')).rejects.toThrow(/timeout/i);
    expect(fetchMock).toHaveBeenCalledTimes(tmdbConfig.maxRetries + 1);
  });

  it('retries a network-level failure (DNS/connection TypeError)', async () => {
    fetchMock
      .mockRejectedValueOnce(new TypeError('fetch failed'))
      .mockResolvedValueOnce(jsonResponse({ ok: true }));

    const result = await client.get('/movie/now_playing');

    expect(result).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('getNowPlaying calls the right path with pagination and language', async () => {
    fetchMock.mockResolvedValue(jsonResponse({ page: 2, results: [] }));

    await client.getNowPlaying(2);

    const [url] = fetchMock.mock.calls[0] as [URL];
    expect(url.pathname).toBe('/3/movie/now_playing');
    expect(url.searchParams.get('page')).toBe('2');
    expect(url.searchParams.get('language')).toBe('pt-BR');
  });
});
