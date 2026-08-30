import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import type {
  CardChargeResult,
  CardGatewayProvider,
} from './card-gateway-provider.interface';

// Simulates a card gateway (Stripe/Pagar.me) processing and confirming a
// tokenized card charge — always approves, since there's no real gateway
// account available to integrate against (per the user, 2026-08-29: "não
// tenho a API, faça uma simulação interna"). The mock only ever reads
// `token`/`amountCents`/`referenceId`; it never receives or touches a card
// number/expiry/CVV, matching what a real gateway integration would also
// never let the backend see (the client tokenizes via Stripe Elements/
// Pagar.me's SDK, never this app).
@Injectable()
export class MockCardGatewayProvider implements CardGatewayProvider {
  charge(
    token: string,
    amountCents: number,
    referenceId: string,
  ): Promise<CardChargeResult> {
    const providerRef = `mock-card-${referenceId}-${amountCents}-${randomUUID()}`;
    void token; // a real gateway would forward this to the card network for authorization
    return Promise.resolve({ providerRef, status: 'paid' });
  }
}
