import { Module } from '@nestjs/common';
import { MockPartnerGateway } from './mock-partner.gateway';
import { PARTNER_TICKETING_GATEWAY } from './partner-ticketing-gateway.interface';

@Module({
  providers: [
    { provide: PARTNER_TICKETING_GATEWAY, useClass: MockPartnerGateway },
  ],
  exports: [PARTNER_TICKETING_GATEWAY],
})
export class PartnerIntegrationModule {}
