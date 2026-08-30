part of 'review_composer_cubit.dart';

enum ReviewComposerStatus { idle, submitting, success, failure }

class ReviewComposerState extends Equatable {
  const ReviewComposerState({
    this.status = ReviewComposerStatus.idle,
    this.failure,
  });

  final ReviewComposerStatus status;
  final Failure? failure;

  @override
  List<Object?> get props => [status, failure];
}
