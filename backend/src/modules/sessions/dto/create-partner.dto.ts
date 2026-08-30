import {
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreatePartnerDto {
  @IsString()
  @MaxLength(120)
  name!: string;

  // Shape is undefined until the real gateway (BE-20/21) exists — accepted
  // as an opaque string for now, not parsed/validated.
  @IsOptional()
  @IsString()
  apiConfig?: string;

  // Required, not optional: a cinema with no location can never be found by
  // BE-14's nearby search, which defeats the point of the entity.
  @IsLatitude()
  latitude!: number;

  @IsLongitude()
  longitude!: number;
}
