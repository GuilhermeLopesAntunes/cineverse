import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/utils/paginated.dart';
import '../../domain/chat_repository.dart';
import '../../domain/entities/chat_room.dart';
import '../../domain/entities/message.dart';
import '../chat_api.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._chatApi, this._failureMapper);

  final ChatApi _chatApi;
  final FailureMapper _failureMapper;

  @override
  Future<ChatRoom> createIndividualRoom(int authorId) async {
    try {
      final model = await _chatApi.createRoom(
        type: 'individual',
        memberIds: [authorId],
      );
      return model.toEntity();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<Paginated<ChatRoom>> fetchRooms({
    required int page,
    int pageSize = 20,
  }) async {
    try {
      final response = await _chatApi.fetchRooms(
        page: page,
        pageSize: pageSize,
      );
      return Paginated(
        items: response.items.map((model) => model.toEntity()).toList(),
        page: response.page,
        pageSize: response.pageSize,
        total: response.total,
        totalPages: response.totalPages,
      );
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<Paginated<Message>> fetchMessages({
    required int roomId,
    required int page,
    int pageSize = 20,
  }) async {
    try {
      final response = await _chatApi.fetchMessages(
        roomId: roomId,
        page: page,
        pageSize: pageSize,
      );
      return Paginated(
        items: response.items.map((model) => model.toEntity()).toList(),
        page: response.page,
        pageSize: response.pageSize,
        total: response.total,
        totalPages: response.totalPages,
      );
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }
}
