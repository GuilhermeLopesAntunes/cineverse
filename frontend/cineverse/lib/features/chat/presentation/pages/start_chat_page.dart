import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_error_view.dart';
import '../cubit/start_chat_cubit.dart';

/// Tela de trânsito: cria/recupera a sala e redireciona para a conversa —
/// não fica visível por mais que um instante no caso comum.
class StartChatPage extends StatefulWidget {
  const StartChatPage({super.key, required this.authorId});

  final int authorId;

  @override
  State<StartChatPage> createState() => _StartChatPageState();
}

class _StartChatPageState extends State<StartChatPage> {
  @override
  void initState() {
    super.initState();
    context.read<StartChatCubit>().start(widget.authorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<StartChatCubit, StartChatState>(
        listener: (context, state) {
          if (state.status == StartChatStatus.success) {
            context.pushReplacement('/chat/${state.room!.id}');
          }
        },
        builder: (context, state) {
          if (state.status == StartChatStatus.failure) {
            return AppErrorView(
              failure: state.failure!,
              onRetry: () =>
                  context.read<StartChatCubit>().start(widget.authorId),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
