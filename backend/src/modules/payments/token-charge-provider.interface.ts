// Shared shape for payment methods that tokenize client-side and confirm
// synchronously against a gateway — Apple Pay/Google Pay (BE-28) and card
// (BE-29) both fit this: the client hands the backend an opaque token, the
// gateway (mocked here — no real Stripe/Pagar.me/wallet credentials
// available) charges it and reports back paid/failed in the same call,
// unlike Pix's separate async webhook (BE-27).
export interface TokenChargeResult {
  providerRef: string;
  status: 'paid' | 'failed';
}

export interface TokenChargeProvider {
  charge(
    token: string,
    amountCents: number,
    referenceId: string,
  ): Promise<TokenChargeResult>;
}
