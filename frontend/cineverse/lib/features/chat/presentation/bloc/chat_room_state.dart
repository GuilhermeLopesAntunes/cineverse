part of 'chat_room_bloc.dart';

enum StateStatus { initial, loading, success, failure }

/// Mensagem exibida + se ainda está esperando confirmação do servidor
/// (inserida otimisticamente ao enviar, substituída quando `newMessage`
/// correspondente chega).
class ChatMessageItem extends Equatable {
  const ChatMessageItem({required this.message, required this.isPending});

  final Message message;
  final bool isPending;

  @override
  List<Object?> get props => [message, isPending];
}

class ChatRoomState extends Equatable {
  const ChatRoomState({
    this.status = StateStatus.initial,
    this.messages = const [],
    this.page = 0,
    this.hasReachedMax = false,
    this.failure,
    this.currentUserId,
  });

  final StateStatus status;

  /// Mais recente primeiro (mesma ordem do servidor) — a tela usa
  /// `ListView(reverse: true)` diretamente sobre esta lista.
  final List<ChatMessageItem> messages;
  final int page;
  final bool hasReachedMax;
  final Failure? failure;
  final int? currentUserId;

  ChatRoomState copyWith({
    StateStatus? status,
    List<ChatMessageItem>? messages,
    int? page,
    bool? hasReachedMax,
    Failure? failure,
    int? currentUserId,
  }) {
    return ChatRoomState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      failure: failure,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    page,
    hasReachedMax,
    failure,
    currentUserId,
  ];
}
