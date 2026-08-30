part of 'push_token_cubit.dart';

enum PushTokenStatus { idle, registering, success, failure }

class PushTokenState extends Equatable {
  const PushTokenState({this.status = PushTokenStatus.idle});

  final PushTokenStatus status;

  @override
  List<Object?> get props => [status];
}
