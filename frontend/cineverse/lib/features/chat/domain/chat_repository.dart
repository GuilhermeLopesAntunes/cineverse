import '../../../core/utils/paginated.dart';
import 'entities/chat_room.dart';
import 'entities/message.dart';

abstract class ChatRepository {
  /// `type: "individual"` é *get-or-create* no servidor — chamar de novo com
  /// o mesmo autor devolve a mesma sala, nunca cria duplicata. Único ponto
  /// de entrada do chat: o `authorId` vem do autor de uma resenha no feed.
  Future<ChatRoom> createIndividualRoom(int authorId);

  Future<Paginated<ChatRoom>> fetchRooms({
    required int page,
    int pageSize = 20,
  });

  Future<Paginated<Message>> fetchMessages({
    required int roomId,
    required int page,
    int pageSize = 20,
  });
}
