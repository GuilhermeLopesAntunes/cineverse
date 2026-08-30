import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/chat_repository.dart';
import '../../domain/entities/chat_room.dart';

part 'start_chat_state.dart';

/// Único ponto de entrada do chat: cria (ou recupera, via *get-or-create* do
/// servidor) a sala individual com o autor de uma resenha.
class StartChatCubit extends Cubit<StartChatState> {
  StartChatCubit(this._chatRepository) : super(const StartChatState());

  final ChatRepository _chatRepository;

  Future<void> start(int authorId) async {
    try {
      final room = await _chatRepository.createIndividualRoom(authorId);
      emit(StartChatState(status: StartChatStatus.success, room: room));
    } on Failure catch (failure) {
      emit(StartChatState(status: StartChatStatus.failure, failure: failure));
    }
  }
}
