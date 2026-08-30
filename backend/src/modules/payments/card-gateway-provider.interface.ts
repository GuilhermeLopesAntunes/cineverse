import type {
  TokenChargeProvider,
  TokenChargeResult,
} from './token-charge-provider.interface';

// Abstraction over a card gateway (RF-12: "gateway tipo Stripe/Pagar.me").
// The client tokenizes the card itself (Stripe Elements / Pagar.me SDK) and
// hands the backend only the resulting opaque token — the backend never
// receives a card number, expiry, or CVV, same guarantee as the wallet
// providers (BE-28). No real, homologated gateway account is available for
// the MVP (per the user, 2026-08-29: "não tenho a API, faça uma simulação
// interna"); `MockCardGatewayProvider` is the only implementation for now —
// a real one plugs in later behind this same interface.

export type CardChargeResult = TokenChargeResult;
export type CardGatewayProvider = TokenChargeProvider;

export const CARD_GATEWAY_PROVIDER = Symbol('CARD_GATEWAY_PROVIDER');
