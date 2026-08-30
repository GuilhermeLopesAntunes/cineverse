import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/core/utils/paginated.dart';
import 'package:cineverse/features/feed/domain/entities/feed_entry.dart';
import 'package:cineverse/features/feed/domain/entities/review.dart';
import 'package:cineverse/features/feed/domain/feed_repository.dart';
import 'package:cineverse/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFeedRepository extends Mock implements FeedRepository {}

Review _spoilerReview() => Review(
  id: 1,
  userId: 42,
  movieId: 1,
  text: null,
  rating: 4,
  hasSpoiler: true,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late MockFeedRepository feedRepository;

  setUp(() {
    feedRepository = MockFeedRepository();
  });

  group('FeedRequested', () {
    blocTest<FeedBloc, FeedState>(
      'resenha com hasSpoiler:true chega com text null e a UI não vaza texto',
      setUp: () =>
          when(
            () => feedRepository.fetchReviews(page: 1, pageSize: 20),
          ).thenAnswer(
            (_) async => Paginated(
              items: [FeedEntry(review: _spoilerReview(), movie: null)],
              page: 1,
              pageSize: 20,
              total: 1,
              totalPages: 1,
            ),
          ),
      build: () => FeedBloc(feedRepository),
      act: (bloc) => bloc.add(const FeedRequested()),
      verify: (bloc) {
        expect(bloc.state.entries.single.review.text, isNull);
        expect(bloc.state.revealedTexts, isEmpty);
      },
    );
  });

  group('ReviewRevealRequested', () {
    blocTest<FeedBloc, FeedState>(
      'revelar afeta apenas o item revelado, guardando o texto em revealedTexts',
      setUp: () {
        when(
          () => feedRepository.fetchReviews(page: 1, pageSize: 20),
        ).thenAnswer(
          (_) async => Paginated(
            items: [FeedEntry(review: _spoilerReview(), movie: null)],
            page: 1,
            pageSize: 20,
            total: 1,
            totalPages: 1,
          ),
        );
        when(() => feedRepository.reveal(1)).thenAnswer(
          (_) async => Review(
            id: 1,
            userId: 42,
            movieId: 1,
            text: 'o mordomo fez',
            rating: 4,
            hasSpoiler: true,
            createdAt: DateTime(2026, 1, 1),
          ),
        );
      },
      build: () => FeedBloc(feedRepository),
      act: (bloc) => bloc
        ..add(const FeedRequested())
        ..add(const ReviewRevealRequested(1)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.revealedTexts[1], 'o mordomo fez');
        // A entrada original na lista continua com text null — só o mapa de
        // revelados muda.
        expect(bloc.state.entries.single.review.text, isNull);
      },
    );

    blocTest<FeedBloc, FeedState>(
      'falha ao revelar não derruba a lista',
      setUp: () {
        when(
          () => feedRepository.fetchReviews(page: 1, pageSize: 20),
        ).thenAnswer(
          (_) async => Paginated(
            items: [FeedEntry(review: _spoilerReview(), movie: null)],
            page: 1,
            pageSize: 20,
            total: 1,
            totalPages: 1,
          ),
        );
        when(() => feedRepository.reveal(1)).thenThrow(const NetworkFailure());
      },
      build: () => FeedBloc(feedRepository),
      act: (bloc) => bloc
        ..add(const FeedRequested())
        ..add(const ReviewRevealRequested(1)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.status, StateStatus.success);
        expect(bloc.state.revealedTexts, isEmpty);
      },
    );
  });
}
