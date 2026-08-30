import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/error/failure.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/ws/socket_factory.dart';
import '../../data/models/message_model.dart';
import '../../domain/chat_repository.dart';
import '../../domain/entities/message.dart';

part 'chat_room_event.dart';
part 'chat_room_state.dart';

const _pageSize = 20;

class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  ChatRoomBloc(this._chatRepository, this._socketFactory, this._tokenStorage)
    : super(const ChatRoomState()) {
    on<ChatMessagesRequested>(_onMessagesRequested);
    on<ChatOlderMessagesRequested>(_onOlderMessagesRequested);
    on<ChatMessageSubmitted>(_onMessageSubmitted);
    on<ChatMessageReceived>(_onMessageReceived);
  }

  final ChatRepository _chatRepository;
  final SocketFactory _socketFactory;
  final TokenStorage _tokenStorage;

  late final int _roomId;
  io.Socket? _socket;

  Future<void> _onMessagesRequested(
    ChatMessagesRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    _roomId = event.roomId;
    emit(const ChatRoomState(status: StateStatus.loading));

    final currentUserId = await _tokenStorage.readUserId();
    try {
      final result = await _chatRepository.fetchMessages(
        roomId: _roomId,
        page: 1,
        pageSize: _pageSize,
      );
      emit(
        ChatRoomState(
          status: StateStatus.success,
          messages: result.items
              .map((m) => ChatMessageItem(message: m, isPending: false))
              .toList(),
          page: result.page,
          hasReachedMax: !result.hasNextPage,
          currentUserId: currentUserId,
        ),
      );
    } on Failure catch (failure) {
      emit(
        ChatRoomState(
          status: StateStatus.failure,
          failure: failure,
          currentUserId: currentUserId,
        ),
      );
      return;
    }

    await _connectSocket(currentUserId);
  }

  Future<void> _connectSocket(int? currentUserId) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) return;

    final socket = _socketFactory.create(
      SocketNamespace.chat,
      accessToken: accessToken,
    );
    _socket = socket;

    // Reenviado a cada conexão (inclusive reconexão) — as salas do servidor
    // não sobrevivem à queda do socket.
    socket.onConnect((_) => socket.emit('joinRoom', {'roomId': _roomId}));
    socket.on(
      'newMessage',
      (data) => add(ChatMessageReceived.fromJson(data as Map<String, dynamic>)),
    );
    socket.connect();
  }

  Future<void> _onOlderMessagesRequested(
    ChatOlderMessagesRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (state.hasReachedMax || state.status == StateStatus.loading) return;
    emit(state.copyWith(status: StateStatus.loading));
    try {
      final result = await _chatRepository.fetchMessages(
        roomId: _roomId,
        page: state.page + 1,
        pageSize: _pageSize,
      );
      emit(
        state.copyWith(
          status: StateStatus.success,
          messages: [
            ...state.messages,
            ...result.items.map(
              (m) => ChatMessageItem(message: m, isPending: false),
            ),
          ],
          page: result.page,
          hasReachedMax: !result.hasNextPage,
        ),
      );
    } on Failure catch (failure) {
      emit(state.copyWith(status: StateStatus.failure, failure: failure));
    }
  }

  void _onMessageSubmitted(
    ChatMessageSubmitted event,
    Emitter<ChatRoomState> emit,
  ) {
    final currentUserId = state.currentUserId;
    if (currentUserId == null) return;

    final pending = Message(
      id: -DateTime.now().microsecondsSinceEpoch,
      roomId: _roomId,
      senderId: currentUserId,
      content: event.content,
      createdAt: DateTime.now(),
    );
    emit(
      state.copyWith(
        messages: [
          ChatMessageItem(message: pending, isPending: true),
          ...state.messages,
        ],
      ),
    );
    _socket?.emit('sendMessage', {'roomId': _roomId, 'content': event.content});
  }

  void _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatRoomState> emit,
  ) {
    final message = event.message;
    final alreadyPresent = state.messages.any(
      (item) => !item.isPending && item.message.id == message.id,
    );
    if (alreadyPresent) return;

    if (message.senderId == state.currentUserId) {
      final pendingIndex = state.messages.indexWhere(
        (item) => item.isPending && item.message.content == message.content,
      );
      if (pendingIndex != -1) {
        final updated = [...state.messages];
        updated[pendingIndex] = ChatMessageItem(
          message: message,
          isPending: false,
        );
        emit(state.copyWith(messages: updated));
        return;
      }
    }

    emit(
      state.copyWith(
        messages: [
          ChatMessageItem(message: message, isPending: false),
          ...state.messages,
        ],
      ),
    );
  }

  @override
  Future<void> close() {
    _socket?.dispose();
    return super.close();
  }
}
