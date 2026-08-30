part of 'chat_rooms_bloc.dart';

enum StateStatus { initial, loading, success, failure }

class ChatRoomsState extends Equatable {
  const ChatRoomsState({
    this.status = StateStatus.initial,
    this.rooms = const [],
    this.page = 0,
    this.hasReachedMax = false,
    this.failure,
  });

  final StateStatus status;
  final List<ChatRoom> rooms;
  final int page;
  final bool hasReachedMax;
  final Failure? failure;

  ChatRoomsState copyWith({
    StateStatus? status,
    List<ChatRoom>? rooms,
    int? page,
    bool? hasReachedMax,
    Failure? failure,
  }) {
    return ChatRoomsState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, rooms, page, hasReachedMax, failure];
}
