import { IsInt, IsOptional } from 'class-validator';

export class CreateOrderItemDto {
  @IsInt()
  seatId!: number;

  // Optional and per seat, not per order — different people in the same
  // group checkout can each pick their own combo, or none at all.
  @IsOptional()
  @IsInt()
  comboItemId?: number;
}
