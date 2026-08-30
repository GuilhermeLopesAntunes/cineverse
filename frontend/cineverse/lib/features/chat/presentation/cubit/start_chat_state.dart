part of 'start_chat_cubit.dart';

enum StartChatStatus { loading, success, failure }

class StartChatState extends Equatable {
  const StartChatState({
    this.status = StartChatStatus.loading,
    this.room,
    this.failure,
  });

  final StartChatStatus status;
  final ChatRoom? room;
  final Failure? failure;

  @override
  List<Object?> get props => [status, room, failure];
}
