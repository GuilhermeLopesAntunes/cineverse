import { Module } from '@nestjs/common';
import { PartnerIntegrationModule } from '../partner-integration/partner-integration.module';
import { SeatsModule } from '../seats/seats.module';
import { TicketsModule } from '../tickets/tickets.module';
import { CARD_GATEWAY_PROVIDER } from './card-gateway-provider.interface';
import { MockCardGatewayProvider } from './mock-card-gateway.provider';
import { MockPixProvider } from './mock-pix.provider';
import { MockWalletProvider } from './mock-wallet.provider';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { PIX_PROVIDER } from './pix-provider.interface';
import { WALLET_PROVIDER } from './wallet-provider.interface';

@Module({
  // SeatsModule (SeatLockService), PartnerIntegrationModule
  // (PARTNER_TICKETING_GATEWAY) and TicketsModule (TicketsService) —
  // settling a paid order (BE-30) confirms the sale with the partner,
  // releases the Redis seat lock, and generates a QR ticket per seat
  // (BE-32).
  imports: [SeatsModule, PartnerIntegrationModule, TicketsModule],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    { provide: PIX_PROVIDER, useClass: MockPixProvider },
    { provide: WALLET_PROVIDER, useClass: MockWalletProvider },
    { provide: CARD_GATEWAY_PROVIDER, useClass: MockCardGatewayProvider },
  ],
})
export class PaymentsModule {}
