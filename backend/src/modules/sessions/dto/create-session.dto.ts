import { IsDateString, IsInt, Min } from 'class-validator';

export class CreateSessionDto {
  @IsInt()
  movieId!: number;

  @IsInt()
  roomId!: number;

  @IsDateString()
  datetime!: string;

  @IsInt()
  @Min(0)
  priceCents!: number;
}
