import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/storage/token_storage.dart';
import 'package:cineverse/core/utils/paginated.dart';
import 'package:cineverse/core/ws/socket_factory.dart';
import 'package:cineverse/features/chat/domain/chat_repository.dart';
import 'package:cineverse/features/chat/domain/entities/message.dart';
import 'package:cineverse/features/chat/presentation/bloc/chat_room_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class MockChatRepository extends Mock implements ChatRepository {}

class MockSocketFactory extends Mock implements SocketFactory {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockSocket extends Mock implements io.Socket {}

void main() {
  late MockChatRepository chatRepository;
  late MockSocketFactory socketFactory;
  late MockTokenStorage tokenStorage;
  late MockSocket socket;
  late void Function(dynamic)? newMessageHandler;

  setUpAll(() {
    registerFallbackValue(SocketNamespace.chat);
  });

  setUp(() {
    chatRepository = MockChatRepository();
    socketFactory = MockSocketFactory();
    tokenStorage = MockTokenStorage();
    socket = MockSocket();
    newMessageHandler = null;

    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => 'token');
    when(() => tokenStorage.readUserId()).thenAnswer((_) async => 1);
    when(
      () => socketFactory.create(any(), accessToken: any(named: 'accessToken')),
    ).thenReturn(socket);
    when(() => socket.connect()).thenReturn(socket);
    when(() => socket.dispose()).thenReturn(null);
    when(() => socket.on(any(), any())).thenAnswer((invocation) {
      final event = invocation.positionalArguments[0] as String;
      if (event == 'newMessage') {
        newMessageHandler =
            invocation.positionalArguments[1] as void Function(dynamic);
      }
      return () {};
    });
    when(
      () => chatRepository.fetchMessages(
        roomId: any(named: 'roomId'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const Paginated(
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
        totalPages: 1,
      ),
    );
  });

  blocTest<ChatRoomBloc, ChatRoomState>(
    'newMessage do próprio remetente substitui a mensagem pendente, sem duplicar',
    build: () => ChatRoomBloc(chatRepository, socketFactory, tokenStorage),
    act: (bloc) async {
      bloc.add(const ChatMessagesRequested(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const ChatMessageSubmitted('oi'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      newMessageHandler!({
        'id': 100,
        'roomId': 1,
        'senderId': 1,
        'content': 'oi',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
    verify: (bloc) {
      expect(bloc.state.messages.length, 1);
      expect(bloc.state.messages.single.isPending, isFalse);
      expect(bloc.state.messages.single.message.id, 100);
    },
  );

  blocTest<ChatRoomBloc, ChatRoomState>(
    'newMessage de outro remetente é apenas anexada',
    build: () => ChatRoomBloc(chatRepository, socketFactory, tokenStorage),
    act: (bloc) async {
      bloc.add(const ChatMessagesRequested(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      newMessageHandler!({
        'id': 200,
        'roomId': 1,
        'senderId': 99,
        'content': 'oi de volta',
        'createdAt': '2026-01-01T00:00:01.000Z',
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
    verify: (bloc) {
      expect(bloc.state.messages.length, 1);
      expect(bloc.state.messages.single.message, isA<Message>());
      expect(bloc.state.messages.single.message.senderId, 99);
    },
  );
}
