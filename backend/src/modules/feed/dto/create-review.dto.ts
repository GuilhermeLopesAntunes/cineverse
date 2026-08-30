import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateReviewDto {
  @IsInt()
  movieId!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  text!: string;

  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  // Behavior (obfuscating content when true) is BE-16 — this DTO just
  // accepts the flag so the column isn't dead weight until then.
  @IsOptional()
  @IsBoolean()
  hasSpoiler: boolean = false;
}
