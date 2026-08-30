import { Controller, Get, Query } from '@nestjs/common';
import { CatalogService, PaginatedMovies } from './catalog.service';
import { ListMoviesQueryDto } from './dto/list-movies-query.dto';

@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('movies')
  listMovies(@Query() query: ListMoviesQueryDto): Promise<PaginatedMovies> {
    return this.catalogService.listMovies(
      query.page,
      query.pageSize,
      query.category,
    );
  }
}
