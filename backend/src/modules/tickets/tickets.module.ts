import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { TicketsController } from './tickets.controller';
import { TicketsService } from './tickets.service';

// No secret registered at the module level (same as AuthModule's
// `JwtModule.register({})`) — `TicketsService` passes `TICKET_QR_SECRET`
// explicitly per call, deliberately never the auth access/refresh secrets.
@Module({
  imports: [JwtModule.register({})],
  controllers: [TicketsController],
  providers: [TicketsService],
  exports: [TicketsService],
})
export class TicketsModule {}
