import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ValidateTicketDto } from './dto/validate-ticket.dto';
import { TicketsService, TicketValidationResult } from './tickets.service';

@Controller('tickets')
export class TicketsController {
  constructor(private readonly ticketsService: TicketsService) {}

  // No @Public() and no dedicated staff/partner role — same MVP
  // simplification as SeatMapController's box-office-sale (BE-22): any
  // authenticated user can call this, there's no staff-auth concept
  // anywhere in this app yet. Standard JWT guard is all that gates it.
  @Post('validate')
  @HttpCode(HttpStatus.OK)
  validate(@Body() dto: ValidateTicketDto): Promise<TicketValidationResult> {
    return this.ticketsService.validate(dto.qrCodePayload);
  }
}
