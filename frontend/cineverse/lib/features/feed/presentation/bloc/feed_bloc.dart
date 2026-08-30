import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/feed_entry.dart';
import '../../domain/entities/review_share.dart';
import '../../domain/feed_repository.dart';

part 'feed_event.dart';
part 'feed_state.dart';

const _pageSize = 20;

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc(this._feedRepository) : super(const FeedState()) {
    on<FeedRequested>(_onRequested);
    on<FeedNextPageRequested>(_onNextPageRequested);
    on<ReviewRevealRequested>(_onRevealRequested);
    on<ReviewShareRequested>(_onShareRequested);
  }

  final FeedRepository _feedRepository;

  Future<void> _onRequested(
    FeedRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(const FeedState(status: StateStatus.loading));
    await _fetchPage(page: 1, emit: emit);
  }

  Future<void> _onNextPageRequested(
    FeedNextPageRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (state.hasReachedMax || state.status == StateStatus.loading) return;
    emit(state.copyWith(status: StateStatus.loading));
    await _fetchPage(
      page: state.page + 1,
      emit: emit,
      previousEntries: state.entries,
    );
  }

  Future<void> _fetchPage({
    required int page,
    required Emitter<FeedState> emit,
    List<FeedEntry> previousEntries = const [],
  }) async {
    try {
      final result = await _feedRepository.fetchReviews(
        page: page,
        pageSize: _pageSize,
      );
      emit(
        state.copyWith(
          status: StateStatus.success,
          entries: [...previousEntries, ...result.items],
          page: result.page,
          hasReachedMax: !result.hasNextPage,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: StateStatus.failure,
          entries: previousEntries,
          failure: failure,
        ),
      );
    }
  }

  Future<void> _onRevealRequested(
    ReviewRevealRequested event,
    Emitter<FeedState> emit,
  ) async {
    try {
      final review = await _feedRepository.reveal(event.reviewId);
      emit(
        state.copyWith(
          revealedTexts: {
            ...state.revealedTexts,
            event.reviewId: review.text ?? '',
          },
        ),
      );
    } on Failure {
      // Falha ao revelar não derruba a lista inteira — o item só continua oculto.
    }
  }

  Future<void> _onShareRequested(
    ReviewShareRequested event,
    Emitter<FeedState> emit,
  ) async {
    try {
      final share = await _feedRepository.share(event.reviewId);
      emit(state.copyWith(pendingShare: share));
    } on Failure {
      // Falha ao buscar os metadados de compartilhamento não é crítica.
    }
  }
}
