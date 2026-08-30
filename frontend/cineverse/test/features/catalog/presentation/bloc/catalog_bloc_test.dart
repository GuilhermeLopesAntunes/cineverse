import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/core/utils/paginated.dart';
import 'package:cineverse/features/catalog/domain/catalog_repository.dart';
import 'package:cineverse/features/catalog/domain/entities/movie.dart';
import 'package:cineverse/features/catalog/domain/entities/movie_category.dart';
import 'package:cineverse/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

Movie _movie(int id) => Movie(
  id: id,
  tmdbId: 1000 + id,
  title: 'Filme $id',
  synopsis: null,
  posterUrl: null,
  cachedAt: DateTime(2026, 1, 1),
);

void main() {
  late MockCatalogRepository catalogRepository;

  setUp(() {
    catalogRepository = MockCatalogRepository();
  });

  group('CatalogCategoryRequested', () {
    blocTest<CatalogBloc, CatalogState>(
      'carrega a primeira página da categoria com sucesso',
      setUp: () => when(
        () => catalogRepository.fetchMovies(
          page: 1,
          pageSize: 20,
          category: MovieCategory.emCartaz,
        ),
      ).thenAnswer(
        (_) async => Paginated(
          items: [_movie(1), _movie(2)],
          page: 1,
          pageSize: 20,
          total: 2,
          totalPages: 1,
        ),
      ),
      build: () => CatalogBloc(catalogRepository),
      act: (bloc) =>
          bloc.add(const CatalogCategoryRequested(MovieCategory.emCartaz)),
      expect: () => [
        isA<CatalogState>().having(
          (s) => s.feedOf(MovieCategory.emCartaz).status,
          'status',
          StateStatus.loading,
        ),
        isA<CatalogState>()
            .having(
              (s) => s.feedOf(MovieCategory.emCartaz).status,
              'status',
              StateStatus.success,
            )
            .having(
              (s) => s.feedOf(MovieCategory.emCartaz).movies,
              'movies',
              [_movie(1), _movie(2)],
            )
            .having(
              (s) => s.feedOf(MovieCategory.emCartaz).hasReachedMax,
              'hasReachedMax',
              true,
            ),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'falha de rede emite failure sem filmes, na categoria correta',
      setUp: () => when(
        () => catalogRepository.fetchMovies(
          page: 1,
          pageSize: 20,
          category: MovieCategory.emBreve,
        ),
      ).thenThrow(const NetworkFailure()),
      build: () => CatalogBloc(catalogRepository),
      act: (bloc) =>
          bloc.add(const CatalogCategoryRequested(MovieCategory.emBreve)),
      expect: () => [
        isA<CatalogState>().having(
          (s) => s.feedOf(MovieCategory.emBreve).status,
          'status',
          StateStatus.loading,
        ),
        isA<CatalogState>()
            .having(
              (s) => s.feedOf(MovieCategory.emBreve).status,
              'status',
              StateStatus.failure,
            )
            .having(
              (s) => s.feedOf(MovieCategory.emBreve).failure,
              'failure',
              const NetworkFailure(),
            ),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'não refaz a requisição se a categoria já tem sucesso carregado',
      build: () => CatalogBloc(catalogRepository),
      seed: () => const CatalogState().copyWithFeed(
        MovieCategory.emCartaz,
        CategoryFeed(status: StateStatus.success, movies: [_movie(1)]),
      ),
      act: (bloc) =>
          bloc.add(const CatalogCategoryRequested(MovieCategory.emCartaz)),
      expect: () => [],
      verify: (_) {
        verifyNever(
          () => catalogRepository.fetchMovies(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            category: any(named: 'category'),
          ),
        );
      },
    );

    blocTest<CatalogBloc, CatalogState>(
      'as categorias são independentes: carregar uma não mexe nas outras',
      setUp: () => when(
        () => catalogRepository.fetchMovies(
          page: 1,
          pageSize: 20,
          category: MovieCategory.lancamento,
        ),
      ).thenAnswer(
        (_) async => Paginated(
          items: [_movie(9)],
          page: 1,
          pageSize: 20,
          total: 1,
          totalPages: 1,
        ),
      ),
      build: () => CatalogBloc(catalogRepository),
      act: (bloc) =>
          bloc.add(const CatalogCategoryRequested(MovieCategory.lancamento)),
      verify: (bloc) {
        expect(
          bloc.state.feedOf(MovieCategory.emCartaz),
          const CategoryFeed(),
        );
        expect(
          bloc.state.feedOf(MovieCategory.emBreve),
          const CategoryFeed(),
        );
      },
    );
  });

  group('CatalogNextPageRequested', () {
    blocTest<CatalogBloc, CatalogState>(
      'concatena a próxima página sem descartar os filmes já carregados',
      setUp: () => when(
        () => catalogRepository.fetchMovies(
          page: 2,
          pageSize: 20,
          category: MovieCategory.emCartaz,
        ),
      ).thenAnswer(
        (_) async => Paginated(
          items: [_movie(3)],
          page: 2,
          pageSize: 20,
          total: 60,
          totalPages: 3,
        ),
      ),
      build: () => CatalogBloc(catalogRepository),
      seed: () => const CatalogState().copyWithFeed(
        MovieCategory.emCartaz,
        CategoryFeed(
          status: StateStatus.success,
          movies: [_movie(1), _movie(2)],
          page: 1,
        ),
      ),
      act: (bloc) =>
          bloc.add(const CatalogNextPageRequested(MovieCategory.emCartaz)),
      expect: () => [
        isA<CatalogState>().having(
          (s) => s.feedOf(MovieCategory.emCartaz).status,
          'status',
          StateStatus.loading,
        ),
        isA<CatalogState>().having(
          (s) => s.feedOf(MovieCategory.emCartaz).movies,
          'movies',
          [_movie(1), _movie(2), _movie(3)],
        ),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'não busca mais páginas quando hasReachedMax já é true',
      build: () => CatalogBloc(catalogRepository),
      seed: () => const CatalogState().copyWithFeed(
        MovieCategory.emCartaz,
        CategoryFeed(
          status: StateStatus.success,
          movies: [_movie(1)],
          hasReachedMax: true,
        ),
      ),
      act: (bloc) =>
          bloc.add(const CatalogNextPageRequested(MovieCategory.emCartaz)),
      expect: () => [],
      verify: (_) {
        verifyNever(
          () => catalogRepository.fetchMovies(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            category: any(named: 'category'),
          ),
        );
      },
    );
  });
}
