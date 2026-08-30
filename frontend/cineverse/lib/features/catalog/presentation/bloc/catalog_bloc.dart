import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/catalog_repository.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_category.dart';

part 'catalog_event.dart';
part 'catalog_state.dart';

const _pageSize = 20;

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc(this._catalogRepository) : super(const CatalogState()) {
    on<CatalogCategoryRequested>(_onCategoryRequested);
    on<CatalogNextPageRequested>(_onNextPageRequested);
  }

  final CatalogRepository _catalogRepository;

  Future<void> _onCategoryRequested(
    CatalogCategoryRequested event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state.feedOf(event.category);
    // `success`/`loading` já têm dado (ou já estão buscando) — trocar de
    // aba de ida e volta não deve refazer a requisição. `failure` é a
    // exceção: permite tentar de novo automaticamente ao voltar pra aba.
    if (current.status == StateStatus.success ||
        current.status == StateStatus.loading) {
      return;
    }
    emit(
      state.copyWithFeed(
        event.category,
        current.copyWith(status: StateStatus.loading),
      ),
    );
    await _fetchPage(category: event.category, page: 1, emit: emit);
  }

  Future<void> _onNextPageRequested(
    CatalogNextPageRequested event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state.feedOf(event.category);
    if (current.hasReachedMax || current.status == StateStatus.loading) {
      return;
    }
    emit(
      state.copyWithFeed(
        event.category,
        current.copyWith(status: StateStatus.loading),
      ),
    );
    await _fetchPage(
      category: event.category,
      page: current.page + 1,
      emit: emit,
      previousMovies: current.movies,
    );
  }

  Future<void> _fetchPage({
    required MovieCategory category,
    required int page,
    required Emitter<CatalogState> emit,
    List<Movie> previousMovies = const [],
  }) async {
    try {
      final result = await _catalogRepository.fetchMovies(
        page: page,
        pageSize: _pageSize,
        category: category,
      );
      emit(
        state.copyWithFeed(
          category,
          CategoryFeed(
            status: StateStatus.success,
            movies: [...previousMovies, ...result.items],
            page: result.page,
            hasReachedMax: !result.hasNextPage,
          ),
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWithFeed(
          category,
          CategoryFeed(
            status: StateStatus.failure,
            movies: previousMovies,
            page: previousMovies.isEmpty ? 0 : page - 1,
            failure: failure,
          ),
        ),
      );
    }
  }
}
