export interface ShareConfig {
  baseUrl: string;
}

export const shareConfig: ShareConfig = {
  // Deep-link/landing-page base for shared reviews — the app itself has no
  // web frontend yet, so this just needs to be a stable, configurable prefix.
  baseUrl: process.env.SHARE_BASE_URL ?? 'https://cineverse.example',
};
