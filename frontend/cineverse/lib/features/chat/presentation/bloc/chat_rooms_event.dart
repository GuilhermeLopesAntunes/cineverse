part of 'chat_rooms_bloc.dart';

sealed class ChatRoomsEvent extends Equatable {
  const ChatRoomsEvent();

  @override
  List<Object?> get props => [];
}

final class ChatRoomsRequested extends ChatRoomsEvent {
  const ChatRoomsRequested();
}

final class ChatRoomsNextPageRequested extends ChatRoomsEvent {
  const ChatRoomsNextPageRequested();
}
