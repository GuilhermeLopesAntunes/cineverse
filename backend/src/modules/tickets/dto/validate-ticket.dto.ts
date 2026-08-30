import { IsString } from 'class-validator';

// Whatever the scanner/app read off the QR code — the entire signed JWT
// from `Ticket.qrCodePayload` (BE-32), verbatim.
export class ValidateTicketDto {
  @IsString()
  qrCodePayload!: string;
}
