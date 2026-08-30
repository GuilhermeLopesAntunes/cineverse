import type { StringValue } from 'ms';

export interface JwtTokenConfig {
  secret: string;
  // `ms`-style duration string (e.g. '15m', '7d') — see the `ms` package for
  // the accepted formats. Cast at the boundary since env vars are always
  // plain strings at compile time.
  expiresIn: StringValue;
}

// Two distinct secrets on purpose: a leaked refresh token must not be usable
// to mint access tokens, and vice versa.
export const accessTokenConfig: JwtTokenConfig = {
  secret: process.env.JWT_ACCESS_SECRET!,
  expiresIn: (process.env.JWT_ACCESS_EXPIRES_IN ?? '15m') as StringValue,
};

export const refreshTokenConfig: JwtTokenConfig = {
  secret: process.env.JWT_REFRESH_SECRET!,
  expiresIn: (process.env.JWT_REFRESH_EXPIRES_IN ?? '7d') as StringValue,
};
