import type {
  TokenChargeProvider,
  TokenChargeResult,
} from './token-charge-provider.interface';

// Abstraction over Apple Pay / Google Pay confirmation (RF-11). Both wallets
// hand the *client* an opaque payment token after the user authorizes with
// Face ID/fingerprint/device PIN — the backend only ever sees that token,
// never a card number, expiry, or CVV. No real, homologated gateway is
// available for the MVP (same situation as BE-20/21 and BE-27);
// `MockWalletProvider` is the only implementation for now.

export type WalletChargeResult = TokenChargeResult;
export type WalletProvider = TokenChargeProvider;

export const WALLET_PROVIDER = Symbol('WALLET_PROVIDER');
