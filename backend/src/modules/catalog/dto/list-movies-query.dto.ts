import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

export type MovieCategoryFilter = 'em_cartaz' | 'lancamento' | 'em_breve';

export const MOVIE_CATEGORY_FILTERS: MovieCategoryFilter[] = [
  'em_cartaz',
  'lancamento',
  'em_breve',
];

export class ListMoviesQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  pageSize: number = 20;

  // Derivado de `releaseDate` no service, não guardado como status próprio
  // (ver comentário em contract.prisma no model Movie).
  @IsOptional()
  @IsIn(MOVIE_CATEGORY_FILTERS)
  category?: MovieCategoryFilter;
}
