part of 'chat_room_bloc.dart';

sealed class ChatRoomEvent extends Equatable {
  const ChatRoomEvent();

  @override
  List<Object?> get props => [];
}

final class ChatMessagesRequested extends ChatRoomEvent {
  const ChatMessagesRequested(this.roomId);

  final int roomId;

  @override
  List<Object?> get props => [roomId];
}

/// Carrega a próxima página (mensagens mais antigas) ao chegar ao topo da
/// rolagem invertida.
final class ChatOlderMessagesRequested extends ChatRoomEvent {
  const ChatOlderMessagesRequested();
}

final class ChatMessageSubmitted extends ChatRoomEvent {
  const ChatMessageSubmitted(this.content);

  final String content;

  @override
  List<Object?> get props => [content];
}

/// Vindo do socket (`newMessage`) — nunca chamado direto de dentro do
/// callback do socket, sempre via `add`.
final class ChatMessageReceived extends ChatRoomEvent {
  ChatMessageReceived.fromJson(Map<String, dynamic> json)
    : message = MessageModel.fromJson(json).toEntity();

  final Message message;

  @override
  List<Object?> get props => [message];
}
