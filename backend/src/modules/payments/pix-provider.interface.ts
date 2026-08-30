// Abstraction over the Pix provider (ARQUITETURA_BACKEND.md § 7: "provedor
// com suporte a Pix dinâmico (sandbox)") — no real, homologated provider is
// available for the MVP, same situation BE-20/21 solved for the partner's
// ticketing system. `MockPixProvider` is the only implementation for now;
// a real one (Efí, Mercado Pago, Asaas, etc.) plugs in later behind this
// same interface without PaymentsService having to change.

export interface PixChargeResult {
  providerRef: string;
  // The "Pix Copia e Cola" payload — a real provider returns the BR Code
  // (EMVCo) string here; the client renders it as a QR code or lets the
  // customer paste it directly into their bank app. Rendering the QR image
  // itself is a client concern, not this interface's.
  copyPasteCode: string;
}

export interface PixProvider {
  createCharge(
    amountCents: number,
    referenceId: string,
  ): Promise<PixChargeResult>;
}

export const PIX_PROVIDER = Symbol('PIX_PROVIDER');
