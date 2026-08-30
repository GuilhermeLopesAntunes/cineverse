import '../../domain/entities/message.dart';

/// Espelha `MessageResponse`: `{ id, roomId, senderId, content, createdAt }`
/// — mesmo formato no histórico REST e no evento `newMessage` do WS.
class MessageModel {
  const MessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as int,
      roomId: json['roomId'] as int,
      senderId: json['senderId'] as int,
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
    );
  }

  final int id;
  final int roomId;
  final int senderId;
  final String content;
  final String createdAt;

  Message toEntity() {
    return Message(
      id: id,
      roomId: roomId,
      senderId: senderId,
      content: content,
      createdAt: DateTime.parse(createdAt).toLocal(),
    );
  }
}
