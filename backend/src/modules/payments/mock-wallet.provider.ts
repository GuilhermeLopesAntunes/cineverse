import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import type {
  WalletChargeResult,
  WalletProvider,
} from './wallet-provider.interface';

// Simulates Apple Pay / Google Pay token confirmation — always approves,
// since there's no real gateway account available to integrate against (per
// the user, 2026-08-29). The mock only ever reads
// `token`/`amountCents`/`referenceId`; it never receives or touches card
// data, matching what a real wallet integration would also never see on the
// backend side.
@Injectable()
export class MockWalletProvider implements WalletProvider {
  charge(
    token: string,
    amountCents: number,
    referenceId: string,
  ): Promise<WalletChargeResult> {
    const providerRef = `mock-wallet-${referenceId}-${amountCents}-${randomUUID()}`;
    void token; // a real gateway would forward this to Apple/Google for verification
    return Promise.resolve({ providerRef, status: 'paid' });
  }
}
