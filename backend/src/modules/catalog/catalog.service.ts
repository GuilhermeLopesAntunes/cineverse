import { Injectable } from '@nestjs/common';
import { db } from '../../prisma/db';
import { MovieCategoryFilter } from './dto/list-movies-query.dto';

export interface MovieListItem {
  id: number;
  tmdbId: number;
  title: string;
  synopsis: string | null;
  posterUrl: string | null;
  cachedAt: string;
  releaseDate: string | null;
}

export interface PaginatedMovies {
  items: MovieListItem[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

// Uma "lançamento" recente deixa de ser lançamento e vira "em cartaz" depois
// desta janela. Puramente um corte de exibição — não existe status próprio
// no banco, só `releaseDate` (ver contract.prisma).
const LANCAMENTO_WINDOW_DAYS = 21;

@Injectable()
export class CatalogService {
  // Serves whatever CatalogSyncService (BE-11) last cached — never calls
  // TMDB itself, so a TMDB outage never blocks a user request
  // (ARQUITETURA_BACKEND.md § 7).
  async listMovies(
    page: number,
    pageSize: number,
    category?: MovieCategoryFilter,
  ): Promise<PaginatedMovies> {
    const offset = (page - 1) * pageSize;
    const baseQuery = this.applyCategoryFilter(category);

    const [items, { total }] = await Promise.all([
      baseQuery.orderBy((m) => m.title.asc()).offset(offset).limit(pageSize).all(),
      baseQuery.aggregate((aggregate) => ({ total: aggregate.count() })),
    ]);

    return {
      items,
      page,
      pageSize,
      total,
      totalPages: Math.max(1, Math.ceil(total / pageSize)),
    };
  }

  // Filtro puramente por data — um filme sem `releaseDate` (TMDB às vezes não
  // anuncia) não casa com nenhuma categoria e por isso não aparece em
  // nenhuma aba filtrada; sem essa data não há como categorizá-lo sem
  // inventar informação.
  private applyCategoryFilter(category: MovieCategoryFilter | undefined) {
    if (!category) return db.orm.public.Movie;

    const now = new Date();
    const windowStart = new Date(
      now.getTime() - LANCAMENTO_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );
    const nowIso = now.toISOString();
    const windowStartIso = windowStart.toISOString();

    switch (category) {
      case 'em_breve':
        return db.orm.public.Movie.where((m) => m.releaseDate.gt(nowIso));
      case 'lancamento':
        return db.orm.public.Movie
          .where((m) => m.releaseDate.gt(windowStartIso))
          .where((m) => m.releaseDate.lte(nowIso));
      case 'em_cartaz':
        return db.orm.public.Movie.where((m) =>
          m.releaseDate.lte(windowStartIso),
        );
    }
  }
}
