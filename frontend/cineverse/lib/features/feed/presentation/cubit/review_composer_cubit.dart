import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/feed_repository.dart';

part 'review_composer_state.dart';

class ReviewComposerCubit extends Cubit<ReviewComposerState> {
  ReviewComposerCubit(this._feedRepository)
    : super(const ReviewComposerState());

  final FeedRepository _feedRepository;

  Future<void> submit({
    required int movieId,
    required String text,
    required int rating,
    required bool hasSpoiler,
  }) async {
    emit(const ReviewComposerState(status: ReviewComposerStatus.submitting));
    try {
      await _feedRepository.createReview(
        movieId: movieId,
        text: text,
        rating: rating,
        hasSpoiler: hasSpoiler,
      );
      emit(const ReviewComposerState(status: ReviewComposerStatus.success));
    } on Failure catch (failure) {
      emit(
        ReviewComposerState(
          status: ReviewComposerStatus.failure,
          failure: failure,
        ),
      );
    }
  }
}
