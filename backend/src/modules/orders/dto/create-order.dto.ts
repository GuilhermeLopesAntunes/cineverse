import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsInt,
  ValidateNested,
} from 'class-validator';
import { CreateOrderItemDto } from './create-order-item.dto';

export class CreateOrderDto {
  @IsInt()
  sessionId!: number;

  // A single item is the "individual" checkout (BE-24); more than one is
  // the "group" one (BE-25) — same shape either way, one buyer, one Order,
  // one OrderItem per seat (optionally with its own combo, BE-26).
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ArrayUnique((item: CreateOrderItemDto) => item.seatId)
  @ValidateNested({ each: true })
  @Type(() => CreateOrderItemDto)
  items!: CreateOrderItemDto[];
}
