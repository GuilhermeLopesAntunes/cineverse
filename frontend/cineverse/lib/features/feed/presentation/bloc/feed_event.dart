part of 'feed_bloc.dart';

sealed class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

final class FeedRequested extends FeedEvent {
  const FeedRequested();
}

final class FeedNextPageRequested extends FeedEvent {
  const FeedNextPageRequested();
}

/// Ação explícita do usuário — nunca automática, já que a ofuscação existe
/// para não vazar o texto antes de o leitor pedir.
final class ReviewRevealRequested extends FeedEvent {
  const ReviewRevealRequested(this.reviewId);

  final int reviewId;

  @override
  List<Object?> get props => [reviewId];
}

final class ReviewShareRequested extends FeedEvent {
  const ReviewShareRequested(this.reviewId);

  final int reviewId;

  @override
  List<Object?> get props => [reviewId];
}
