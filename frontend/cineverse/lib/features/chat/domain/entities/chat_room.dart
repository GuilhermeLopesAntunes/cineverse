import 'package:equatable/equatable.dart';

enum ChatRoomType { individual, group }

/// `POST /chat/rooms` (get-or-create para `individual`) e `GET /chat/rooms`.
/// Não traz `memberIds` — a API não devolve isso no objeto da sala.
class ChatRoom extends Equatable {
  const ChatRoom({
    required this.id,
    required this.type,
    required this.createdAt,
  });

  final int id;
  final ChatRoomType type;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, type, createdAt];
}
