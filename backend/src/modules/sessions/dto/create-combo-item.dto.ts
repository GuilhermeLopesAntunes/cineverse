import { IsInt, IsString, Min, MaxLength } from 'class-validator';

export class CreateComboItemDto {
  @IsString()
  @MaxLength(120)
  name!: string;

  @IsInt()
  @Min(0)
  priceCents!: number;
}
