import '../../../core/api/api_client.dart';
import '../../../core/utils/paginated.dart';
import 'models/review_model.dart';
import 'models/review_share_model.dart';

class FeedApi {
  FeedApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Paginated<ReviewModel>> fetchReviews({
    required int page,
    required int pageSize,
  }) async {
    final response = await _apiClient.dio.get(
      '/reviews',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return Paginated.fromJson(
      response.data as Map<String, dynamic>,
      (item) => ReviewModel.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<ReviewModel> createReview({
    required int movieId,
    required String text,
    required int rating,
    required bool hasSpoiler,
  }) async {
    final response = await _apiClient.dio.post(
      '/reviews',
      data: {
        'movieId': movieId,
        'text': text,
        'rating': rating,
        'hasSpoiler': hasSpoiler,
      },
    );
    return ReviewModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReviewModel> reveal(int reviewId) async {
    final response = await _apiClient.dio.get('/reviews/$reviewId/reveal');
    return ReviewModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReviewShareModel> share(int reviewId) async {
    final response = await _apiClient.dio.get('/reviews/$reviewId/share');
    return ReviewShareModel.fromJson(response.data as Map<String, dynamic>);
  }
}
