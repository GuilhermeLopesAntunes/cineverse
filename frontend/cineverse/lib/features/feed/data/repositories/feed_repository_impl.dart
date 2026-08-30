import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/utils/paginated.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../domain/entities/feed_entry.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_share.dart';
import '../../domain/feed_repository.dart';
import '../feed_api.dart';

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl(
    this._feedApi,
    this._catalogRepository,
    this._failureMapper,
  );

  final FeedApi _feedApi;
  final CatalogRepository _catalogRepository;
  final FailureMapper _failureMapper;

  @override
  Future<Paginated<FeedEntry>> fetchReviews({
    required int page,
    int pageSize = 20,
  }) async {
    try {
      final response = await _feedApi.fetchReviews(
        page: page,
        pageSize: pageSize,
      );
      final entries = response.items
          .map(
            (model) => FeedEntry(
              review: model.toEntity(),
              movie: _catalogRepository.movieById(model.movieId),
            ),
          )
          .toList();
      return Paginated(
        items: entries,
        page: response.page,
        pageSize: response.pageSize,
        total: response.total,
        totalPages: response.totalPages,
      );
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<Review> createReview({
    required int movieId,
    required String text,
    required int rating,
    required bool hasSpoiler,
  }) async {
    try {
      final model = await _feedApi.createReview(
        movieId: movieId,
        text: text,
        rating: rating,
        hasSpoiler: hasSpoiler,
      );
      return model.toEntity();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<Review> reveal(int reviewId) async {
    try {
      final model = await _feedApi.reveal(reviewId);
      return model.toEntity();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<ReviewShare> share(int reviewId) async {
    try {
      final model = await _feedApi.share(reviewId);
      return model.toEntity();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }
}
