import '../../../core/api/api_client.dart';
import '../../../core/utils/paginated.dart';
import 'models/chat_room_model.dart';
import 'models/message_model.dart';

class ChatApi {
  ChatApi(this._apiClient);

  final ApiClient _apiClient;

  /// O próprio usuário autenticado **não** entra em `memberIds` — o backend
  /// o adiciona sozinho.
  Future<ChatRoomModel> createRoom({
    required String type,
    required List<int> memberIds,
  }) async {
    final response = await _apiClient.dio.post(
      '/chat/rooms',
      data: {'type': type, 'memberIds': memberIds},
    );
    return ChatRoomModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Paginated<ChatRoomModel>> fetchRooms({
    required int page,
    required int pageSize,
  }) async {
    final response = await _apiClient.dio.get(
      '/chat/rooms',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return Paginated.fromJson(
      response.data as Map<String, dynamic>,
      (item) => ChatRoomModel.fromJson(item as Map<String, dynamic>),
    );
  }

  Future<Paginated<MessageModel>> fetchMessages({
    required int roomId,
    required int page,
    required int pageSize,
  }) async {
    final response = await _apiClient.dio.get(
      '/chat/rooms/$roomId/messages',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return Paginated.fromJson(
      response.data as Map<String, dynamic>,
      (item) => MessageModel.fromJson(item as Map<String, dynamic>),
    );
  }
}
