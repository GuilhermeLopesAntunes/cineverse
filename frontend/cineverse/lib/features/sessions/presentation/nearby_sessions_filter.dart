/// Passado via `extra` ao navegar do detalhe de um filme para "/nearby" —
/// `GET /sessions/nearby` não filtra por filme (só existe filtro por
/// proximidade), então a tela pede a lista inteira do parceiro mais
/// próximo e filtra no cliente, do mesmo jeito que o feed resolve resenhas
/// por filme (ARQUITETURA_FRONTEND.md § 11, atrito 5).
class NearbySessionsFilter {
  const NearbySessionsFilter({required this.movieId, required this.movieTitle});

  final int movieId;
  final String movieTitle;
}
