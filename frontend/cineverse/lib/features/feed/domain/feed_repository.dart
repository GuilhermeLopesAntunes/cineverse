import '../../../core/utils/paginated.dart';
import 'entities/feed_entry.dart';
import 'entities/review.dart';
import 'entities/review_share.dart';

abstract class FeedRepository {
  Future<Paginated<FeedEntry>> fetchReviews({
    required int page,
    int pageSize = 20,
  });

  Future<Review> createReview({
    required int movieId,
    required String text,
    required int rating,
    required bool hasSpoiler,
  });

  /// Sempre devolve o texto real, mesmo para uma resenha com spoiler.
  Future<Review> reveal(int reviewId);

  Future<ReviewShare> share(int reviewId);
}
