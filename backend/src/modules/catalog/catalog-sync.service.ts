import { Injectable, Logger } from '@nestjs/common';
import { db } from '../../prisma/db';
import { TmdbClient, TmdbMovie } from './tmdb/tmdb.client';

// TMDB's own now_playing listing is already just a handful of pages; this
// only guards against an unexpectedly huge total_pages value ballooning one
// sync run.
const MAX_PAGES = 10;
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p/w500';

export interface CatalogSyncResult {
  pagesFetched: number;
  moviesSynced: number;
}

@Injectable()
export class CatalogSyncService {
  private readonly logger = new Logger(CatalogSyncService.name);

  constructor(private readonly tmdbClient: TmdbClient) {}

  async syncNowPlaying(): Promise<CatalogSyncResult> {
    return this.syncPages((page) => this.tmdbClient.getNowPlaying(page));
  }

  // Mesma paginação do now_playing, contra o endpoint "upcoming" do TMDB —
  // é a única fonte de filme com releaseDate no futuro; now_playing por
  // definição só traz filme já lançado.
  async syncUpcoming(): Promise<CatalogSyncResult> {
    return this.syncPages((page) => this.tmdbClient.getUpcoming(page));
  }

  private async syncPages(
    fetchPage: (
      page: number,
    ) => Promise<{ results: TmdbMovie[]; total_pages: number }>,
  ): Promise<CatalogSyncResult> {
    let page = 1;
    let totalPages = 1;
    let moviesSynced = 0;

    do {
      const response = await fetchPage(page);
      totalPages = Math.min(response.total_pages, MAX_PAGES);

      for (const movie of response.results) {
        await this.upsertMovie(movie);
        moviesSynced++;
      }

      page++;
    } while (page <= totalPages);

    this.logger.log(
      `Catalog sync done: ${moviesSynced} movies across ${totalPages} page(s)`,
    );
    return { pagesFetched: totalPages, moviesSynced };
  }

  private async upsertMovie(movie: TmdbMovie): Promise<void> {
    const cachedAt = new Date().toISOString();
    const posterUrl = movie.poster_path
      ? `${TMDB_IMAGE_BASE}${movie.poster_path}`
      : null;
    // TMDB devolve "YYYY-MM-DD" (ou "" para filme sem data anunciada) — a
    // coluna é timestamptz, então precisa de um ISO completo; "" vira null
    // em vez de virar uma Date inválida.
    const releaseDate = movie.release_date
      ? new Date(movie.release_date).toISOString()
      : null;
    const fields = {
      title: movie.title,
      synopsis: movie.overview,
      posterUrl,
      cachedAt,
      releaseDate,
    };

    // Not `.upsert()`: its conflict detection only seems to key off the
    // model's primary key (`id`, autoincrement here), not an arbitrary
    // `@unique` field — verified against a real DB, every call to
    // `.upsert({ create: { tmdbId, ... } })` did a plain INSERT regardless
    // of whether that tmdbId already existed, and blew up on the second
    // sync run with "duplicate key value violates unique constraint". Check
    // by the field that's actually unique, then create or update explicitly.
    const existing = await db.orm.public.Movie.where({
      tmdbId: movie.id,
    }).first();
    if (existing) {
      await db.orm.public.Movie.where({ tmdbId: movie.id }).update(fields);
    } else {
      await db.orm.public.Movie.create({ tmdbId: movie.id, ...fields });
    }
  }
}
