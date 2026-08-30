import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/chat_repository.dart';
import '../../domain/entities/chat_room.dart';

part 'chat_rooms_event.dart';
part 'chat_rooms_state.dart';

const _pageSize = 20;

class ChatRoomsBloc extends Bloc<ChatRoomsEvent, ChatRoomsState> {
  ChatRoomsBloc(this._chatRepository) : super(const ChatRoomsState()) {
    on<ChatRoomsRequested>(_onRequested);
    on<ChatRoomsNextPageRequested>(_onNextPageRequested);
  }

  final ChatRepository _chatRepository;

  Future<void> _onRequested(
    ChatRoomsRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    emit(const ChatRoomsState(status: StateStatus.loading));
    await _fetchPage(page: 1, emit: emit);
  }

  Future<void> _onNextPageRequested(
    ChatRoomsNextPageRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    if (state.hasReachedMax || state.status == StateStatus.loading) return;
    emit(state.copyWith(status: StateStatus.loading));
    await _fetchPage(
      page: state.page + 1,
      emit: emit,
      previousRooms: state.rooms,
    );
  }

  Future<void> _fetchPage({
    required int page,
    required Emitter<ChatRoomsState> emit,
    List<ChatRoom> previousRooms = const [],
  }) async {
    try {
      final result = await _chatRepository.fetchRooms(
        page: page,
        pageSize: _pageSize,
      );
      emit(
        ChatRoomsState(
          status: StateStatus.success,
          rooms: [...previousRooms, ...result.items],
          page: result.page,
          hasReachedMax: !result.hasNextPage,
        ),
      );
    } on Failure catch (failure) {
      emit(
        ChatRoomsState(
          status: StateStatus.failure,
          rooms: previousRooms,
          failure: failure,
        ),
      );
    }
  }
}
