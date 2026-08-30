import { Module } from '@nestjs/common';
import { SeatsModule } from '../seats/seats.module';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

@Module({
  imports: [SeatsModule],
  controllers: [OrdersController],
  providers: [OrdersService],
})
export class OrdersModule {}
