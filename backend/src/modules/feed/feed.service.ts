import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { shareConfig } from './feed.config';
import { CreateReviewDto } from './dto/create-review.dto';

export interface ReviewResponse {
  id: number;
  userId: number;
  movieId: number;
  // null when the post is marked as a spoiler and hasn't been explicitly
  // revealed (see FeedService.reveal) — never a real empty review.
  text: string | null;
  rating: number;
  hasSpoiler: boolean;
  createdAt: string;
}

interface RawReview {
  id: number;
  userId: number;
  movieId: number;
  text: string;
  rating: number;
  hasSpoiler: boolean;
  createdAt: string;
}

export interface PaginatedReviews {
  items: ReviewResponse[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export interface ShareReviewResponse {
  url: string;
  title: string;
  text: string;
}

const REVIEW_FIELDS = [
  'id',
  'userId',
  'movieId',
  'text',
  'rating',
  'hasSpoiler',
  'createdAt',
] as const;

// Hidden by default, per BE-16's criterion — callers that want the real
// text go through `reveal()`, an explicit action, not a query flag on the
// feed itself (that would defeat "hidden by default").
function obfuscateIfSpoiler(review: RawReview): ReviewResponse {
  return { ...review, text: review.hasSpoiler ? null : review.text };
}

@Injectable()
export class FeedService {
  async create(userId: number, dto: CreateReviewDto): Promise<ReviewResponse> {
    const movie = await db.orm.public.Movie.where({ id: dto.movieId }).first();
    if (!movie) {
      throw new NotFoundException(`Filme ${dto.movieId} não encontrado`);
    }

    // The author sees their own text back immediately — no point hiding
    // from the person who just wrote it.
    return db.orm.public.Review.select(...REVIEW_FIELDS).create({
      userId,
      movieId: dto.movieId,
      text: dto.text,
      rating: dto.rating,
      hasSpoiler: dto.hasSpoiler,
    });
  }

  // Newest first — the point of a feed is what the community just posted.
  async list(page: number, pageSize: number): Promise<PaginatedReviews> {
    const offset = (page - 1) * pageSize;

    const [items, { total }] = await Promise.all([
      db.orm.public.Review.select(...REVIEW_FIELDS)
        .orderBy((r) => r.createdAt.desc())
        .offset(offset)
        .limit(pageSize)
        .all(),
      db.orm.public.Review.aggregate((aggregate) => ({
        total: aggregate.count(),
      })),
    ]);

    return {
      items: items.map(obfuscateIfSpoiler),
      page,
      pageSize,
      total,
      totalPages: Math.max(1, Math.ceil(total / pageSize)),
    };
  }

  // The explicit "reveal" action — always returns the real text, spoiler or
  // not. There's no partial/half-reveal state: the client asked, it gets it.
  async reveal(id: number): Promise<ReviewResponse> {
    const review = await db.orm.public.Review.where({ id })
      .select(...REVIEW_FIELDS)
      .first();
    if (!review) {
      throw new NotFoundException(`Resenha ${id} não encontrada`);
    }
    return review;
  }

  // Metadata for the client's native share sheet (Instagram/TikTok/etc. —
  // the actual post happens client-side, this just pre-formats the content).
  // Built from the obfuscated view, not the raw row: a spoiler-marked review
  // must not leak its text through sharing either, or BE-16 would be moot.
  async share(id: number): Promise<ShareReviewResponse> {
    const review = await db.orm.public.Review.where({ id })
      .select(...REVIEW_FIELDS)
      .first();
    if (!review) {
      throw new NotFoundException(`Resenha ${id} não encontrada`);
    }

    const movie = await db.orm.public.Movie.where({
      id: review.movieId,
    }).first();
    const movieTitle = movie?.title ?? 'um filme';
    const { text } = obfuscateIfSpoiler(review);
    const body =
      text ?? 'Contém spoiler — revele no app para ver a resenha completa.';

    const title = `Resenha de ${movieTitle} no CineVerse`;
    return {
      url: `${shareConfig.baseUrl}/reviews/${review.id}`,
      title,
      text: `${title}\nNota: ${review.rating}/5\n${body}`,
    };
  }
}
