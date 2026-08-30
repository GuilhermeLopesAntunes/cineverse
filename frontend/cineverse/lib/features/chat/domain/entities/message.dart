import 'package:equatable/equatable.dart';

/// `GET /chat/rooms/:roomId/messages` (REST, histórico) e o evento
/// `newMessage` (WS, tempo real) — mesmo formato nos dois casos.
class Message extends Equatable {
  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int roomId;
  final int senderId;
  final String content;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, roomId, senderId, content, createdAt];
}
