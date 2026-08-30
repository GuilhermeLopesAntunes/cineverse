import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_error_view.dart';
import '../bloc/chat_room_bloc.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key, required this.roomId});

  final int roomId;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ChatRoomBloc>().add(ChatMessagesRequested(widget.roomId));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Lista invertida: o topo da rolagem é o fim da lista de dados.
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      context.read<ChatRoomBloc>().add(const ChatOlderMessagesRequested());
    }
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    context.read<ChatRoomBloc>().add(ChatMessageSubmitted(text));
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sala #${widget.roomId}')),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatRoomBloc, ChatRoomState>(
              builder: (context, state) {
                if (state.status == StateStatus.initial ||
                    (state.status == StateStatus.loading &&
                        state.messages.isEmpty)) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == StateStatus.failure &&
                    state.messages.isEmpty) {
                  return AppErrorView(
                    failure: state.failure!,
                    onRetry: () => context.read<ChatRoomBloc>().add(
                      ChatMessagesRequested(widget.roomId),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final item = state.messages[index];
                    final isMine = item.message.senderId == state.currentUserId;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Opacity(
                          opacity: item.isPending ? 0.6 : 1,
                          child: Text(item.message.content),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Mensagem',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _submit),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
