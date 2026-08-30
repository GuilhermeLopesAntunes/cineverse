part of 'catalog_bloc.dart';

enum StateStatus { initial, loading, success, failure }

/// Estado de uma única aba de categoria — mesma forma que o antigo
/// `CatalogState` de lista única, só que agora uma cópia por categoria.
class CategoryFeed extends Equatable {
  const CategoryFeed({
    this.status = StateStatus.initial,
    this.movies = const [],
    this.page = 0,
    this.hasReachedMax = false,
    this.failure,
  });

  final StateStatus status;
  final List<Movie> movies;
  final int page;
  final bool hasReachedMax;
  final Failure? failure;

  CategoryFeed copyWith({
    StateStatus? status,
    List<Movie>? movies,
    int? page,
    bool? hasReachedMax,
    Failure? failure,
  }) {
    return CategoryFeed(
      status: status ?? this.status,
      movies: movies ?? this.movies,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, movies, page, hasReachedMax, failure];
}

class CatalogState extends Equatable {
  const CatalogState({
    this.feeds = const {
      MovieCategory.emCartaz: CategoryFeed(),
      MovieCategory.lancamento: CategoryFeed(),
      MovieCategory.emBreve: CategoryFeed(),
    },
  });

  final Map<MovieCategory, CategoryFeed> feeds;

  CategoryFeed feedOf(MovieCategory category) =>
      feeds[category] ?? const CategoryFeed();

  CatalogState copyWithFeed(MovieCategory category, CategoryFeed feed) {
    return CatalogState(feeds: {...feeds, category: feed});
  }

  @override
  List<Object?> get props => [feeds];
}
