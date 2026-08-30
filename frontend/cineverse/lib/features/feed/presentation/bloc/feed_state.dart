part of 'feed_bloc.dart';

enum StateStatus { initial, loading, success, failure }

class FeedState extends Equatable {
  const FeedState({
    this.status = StateStatus.initial,
    this.entries = const [],
    this.page = 0,
    this.hasReachedMax = false,
    this.failure,
    this.revealedTexts = const {},
    this.pendingShare,
  });

  final StateStatus status;
  final List<FeedEntry> entries;
  final int page;
  final bool hasReachedMax;
  final Failure? failure;

  /// Texto revelado por `reviewId` — vive só enquanto esta tela existir
  /// (Bloc por instância de tela); sair e voltar restaura o estado oculto.
  final Map<int, String> revealedTexts;

  /// Resultado da última chamada de `share`, consumido por um
  /// `BlocListener` que abre a share sheet nativa. Não precisa de "consumido
  /// explícito": só muda de valor quando um novo compartilhamento é pedido.
  final ReviewShare? pendingShare;

  FeedState copyWith({
    StateStatus? status,
    List<FeedEntry>? entries,
    int? page,
    bool? hasReachedMax,
    Failure? failure,
    Map<int, String>? revealedTexts,
    ReviewShare? pendingShare,
  }) {
    return FeedState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      failure: failure,
      revealedTexts: revealedTexts ?? this.revealedTexts,
      pendingShare: pendingShare ?? this.pendingShare,
    );
  }

  @override
  List<Object?> get props => [
    status,
    entries,
    page,
    hasReachedMax,
    failure,
    revealedTexts,
    pendingShare,
  ];
}
