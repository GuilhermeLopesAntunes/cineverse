export class TmdbConfigError extends Error {}

export class TmdbRequestError extends Error {
  // `status` undefined means the failure never got an HTTP response at all
  // (timeout or network error) — treated as retryable, same as 5xx/429.
  constructor(
    message: string,
    readonly status?: number,
  ) {
    super(message);
    this.name = 'TmdbRequestError';
  }
}
