import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/features/notifications/domain/notifications_repository.dart';
import 'package:cineverse/features/notifications/presentation/cubit/push_token_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

void main() {
  late MockNotificationsRepository notificationsRepository;

  setUp(() {
    notificationsRepository = MockNotificationsRepository();
  });

  blocTest<PushTokenCubit, PushTokenState>(
    'registra com sucesso',
    setUp: () => when(
      () => notificationsRepository.registerDeviceToken(),
    ).thenAnswer((_) async {}),
    build: () =>
        PushTokenCubit(notificationsRepository, requestPermission: () async {}),
    act: (cubit) => cubit.register(),
    expect: () => [
      const PushTokenState(status: PushTokenStatus.registering),
      const PushTokenState(status: PushTokenStatus.success),
    ],
  );

  blocTest<PushTokenCubit, PushTokenState>(
    'falha ao registrar não é crítica — emite failure',
    setUp: () => when(
      () => notificationsRepository.registerDeviceToken(),
    ).thenThrow(const NetworkFailure()),
    build: () =>
        PushTokenCubit(notificationsRepository, requestPermission: () async {}),
    act: (cubit) => cubit.register(),
    expect: () => [
      const PushTokenState(status: PushTokenStatus.registering),
      const PushTokenState(status: PushTokenStatus.failure),
    ],
  );

  blocTest<PushTokenCubit, PushTokenState>(
    'chamar register() duas vezes só registra uma — idempotente no cliente',
    setUp: () => when(
      () => notificationsRepository.registerDeviceToken(),
    ).thenAnswer((_) async {}),
    build: () =>
        PushTokenCubit(notificationsRepository, requestPermission: () async {}),
    act: (cubit) async {
      await cubit.register();
      await cubit.register();
    },
    expect: () => [
      const PushTokenState(status: PushTokenStatus.registering),
      const PushTokenState(status: PushTokenStatus.success),
    ],
    verify: (_) {
      verify(() => notificationsRepository.registerDeviceToken()).called(1);
    },
  );
}
