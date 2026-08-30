import { Type } from 'class-transformer';
import { IsInt, IsOptional } from 'class-validator';

export class ListSessionsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  roomId?: number;
}
