import { Module } from '@nestjs/common';
import { PartnerIntegrationModule } from '../partner-integration/partner-integration.module';
import { SeatLockService } from './seat-lock.service';
import { SeatMapController } from './seat-map.controller';
import { SeatMapService } from './seat-map.service';
import { SeatsController } from './seats.controller';
import { SeatsGateway } from './seats.gateway';
import { SeatsService } from './seats.service';

@Module({
  imports: [PartnerIntegrationModule],
  controllers: [SeatsController, SeatMapController],
  providers: [SeatsService, SeatMapService, SeatLockService, SeatsGateway],
  // OrdersModule (BE-24) needs this to verify a buyer actually holds the
  // seats they're checking out before writing an Order.
  exports: [SeatLockService],
})
export class SeatsModule {}
