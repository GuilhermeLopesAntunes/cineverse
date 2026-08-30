import { IsInt } from 'class-validator';

export class SeatActionDto {
  @IsInt()
  sessionId!: number;

  @IsInt()
  seatId!: number;
}
