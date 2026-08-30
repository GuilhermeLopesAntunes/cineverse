part of 'catalog_bloc.dart';

sealed class CatalogEvent extends Equatable {
  const CatalogEvent();

  @override
  List<Object?> get props => [];
}

/// Primeira carga de uma aba de categoria — disparado ao entrar na tela e ao
/// trocar de aba pela primeira vez (não recarrega se já tiver sucesso).
final class CatalogCategoryRequested extends CatalogEvent {
  const CatalogCategoryRequested(this.category);

  final MovieCategory category;

  @override
  List<Object?> get props => [category];
}

/// Disparado ao chegar perto do fim da rolagem de uma aba.
final class CatalogNextPageRequested extends CatalogEvent {
  const CatalogNextPageRequested(this.category);

  final MovieCategory category;

  @override
  List<Object?> get props => [category];
}
