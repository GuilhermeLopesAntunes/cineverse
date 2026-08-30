/// Espelha `MovieCategoryFilter` do backend (`GET /catalog/movies?category=`)
/// — a categorização é derivada de `releaseDate` inteiramente no servidor;
/// o cliente só nomeia e rotula o mesmo conjunto de valores.
enum MovieCategory {
  emCartaz,
  lancamento,
  emBreve;

  String get queryValue => switch (this) {
    MovieCategory.emCartaz => 'em_cartaz',
    MovieCategory.lancamento => 'lancamento',
    MovieCategory.emBreve => 'em_breve',
  };

  String get label => switch (this) {
    MovieCategory.emCartaz => 'Em cartaz',
    MovieCategory.lancamento => 'Lançamento',
    MovieCategory.emBreve => 'Em breve',
  };
}
