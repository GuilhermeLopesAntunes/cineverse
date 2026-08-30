import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import type { PixChargeResult, PixProvider } from './pix-provider.interface';

// Simulates a Pix provider — no real, homologated one available for the
// MVP (RD-03's compliance sign-off is a business process the provider
// itself handles, not something to build here). The "copy-paste code" is
// deliberately NOT a real EMVCo/BR Code payload — reproducing that spec
// (TLV encoding, CRC16 checksum) would just be faithfully faking a format
// no real bank will ever parse; a clearly-fake token is more honest about
// what this is.
@Injectable()
export class MockPixProvider implements PixProvider {
  createCharge(
    amountCents: number,
    referenceId: string,
  ): Promise<PixChargeResult> {
    const providerRef = `mock-pix-${randomUUID()}`;
    return Promise.resolve({
      providerRef,
      copyPasteCode: `00020101-MOCK-PIX-${referenceId}-${amountCents}-${providerRef}`,
    });
  }
}
