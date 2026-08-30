import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../bloc/chat_rooms_bloc.dart';

class ChatRoomsPage extends StatefulWidget {
  const ChatRoomsPage({super.key});

  @override
  State<ChatRoomsPage> createState() => _ChatRoomsPageState();
}

class _ChatRoomsPageState extends State<ChatRoomsPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ChatRoomsBloc>().add(const ChatRoomsRequested());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      context.read<ChatRoomsBloc>().add(const ChatRoomsNextPageRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversas')),
      body: BlocBuilder<ChatRoomsBloc, ChatRoomsState>(
        builder: (context, state) {
          if (state.status == StateStatus.initial ||
              (state.status == StateStatus.loading && state.rooms.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == StateStatus.failure && state.rooms.isEmpty) {
            return AppErrorView(
              failure: state.failure!,
              onRetry: () =>
                  context.read<ChatRoomsBloc>().add(const ChatRoomsRequested()),
            );
          }
          if (state.rooms.isEmpty) {
            return const EmptyState(
              message:
                  'Nenhuma conversa ainda. Inicie uma a partir do autor de uma resenha no feed.',
              icon: Icons.chat_bubble_outline,
            );
          }
          return ListView.builder(
            controller: _scrollController,
            itemCount: state.rooms.length + (state.hasReachedMax ? 0 : 1),
            itemBuilder: (context, index) {
              if (index >= state.rooms.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final room = state.rooms[index];
              return ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text('Sala #${room.id}'),
                subtitle: Text(Formatters.dateTime(room.createdAt)),
                onTap: () => context.push('/chat/${room.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
