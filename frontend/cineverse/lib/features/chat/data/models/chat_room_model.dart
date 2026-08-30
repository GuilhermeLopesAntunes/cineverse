import '../../domain/entities/chat_room.dart';

/// Espelha `ChatRoomResponse`: `{ id, type, createdAt }`.
class ChatRoomModel {
  const ChatRoomModel({
    required this.id,
    required this.type,
    required this.createdAt,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'] as int,
      type: json['type'] as String,
      createdAt: json['createdAt'] as String,
    );
  }

  final int id;
  final String type;
  final String createdAt;

  ChatRoom toEntity() {
    return ChatRoom(
      id: id,
      type: type == 'group' ? ChatRoomType.group : ChatRoomType.individual,
      createdAt: DateTime.parse(createdAt).toLocal(),
    );
  }
}
