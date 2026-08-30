import { IsString, MaxLength } from 'class-validator';

export class BroadcastPromotionDto {
  @IsString()
  @MaxLength(120)
  title!: string;

  @IsString()
  @MaxLength(500)
  body!: string;
}
