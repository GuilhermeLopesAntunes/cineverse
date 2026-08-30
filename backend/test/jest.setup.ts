// Deterministic fallbacks so the test suite never depends on a local .env
// file existing (CI has none). `??=` still lets a real .env value win when
// one is present, e.g. for a developer running tests locally.
process.env.JWT_ACCESS_SECRET ??= 'test-access-secret';
process.env.JWT_ACCESS_EXPIRES_IN ??= '15m';
process.env.JWT_REFRESH_SECRET ??= 'test-refresh-secret';
process.env.JWT_REFRESH_EXPIRES_IN ??= '7d';
process.env.TICKET_QR_SECRET ??= 'test-ticket-qr-secret';
process.env.TMDB_API_KEY ??= 'test-tmdb-key';
// Real retries would otherwise slow every failure-path test down by
// hundreds of ms of exponential backoff for no reason.
process.env.TMDB_RETRY_BASE_MS ??= '1';
