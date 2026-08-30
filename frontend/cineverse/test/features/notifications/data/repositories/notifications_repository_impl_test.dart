import 'package:cineverse/core/error/failure_mapper.dart';
import 'package:cineverse/core/storage/installation_id_storage.dart';
import 'package:cineverse/features/notifications/data/notifications_api.dart';
import 'package:cineverse/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsApi extends Mock implements NotificationsApi {}

class MockInstallationIdStorage extends Mock implements InstallationIdStorage {}

void main() {
  late MockNotificationsApi notificationsApi;
  late MockInstallationIdStorage installationIdStorage;

  setUp(() {
    notificationsApi = MockNotificationsApi();
    installationIdStorage = MockInstallationIdStorage();
    when(
      () => installationIdStorage.readOrCreate(),
    ).thenAnswer((_) async => 'installation-123');
    when(
      () => notificationsApi.registerPushToken(
        token: any(named: 'token'),
        platform: any(named: 'platform'),
      ),
    ).thenAnswer((_) async {});
  });

  test('Android envia platform:"android"', () async {
    final repository = NotificationsRepositoryImpl(
      notificationsApi,
      installationIdStorage,
      const FailureMapper(),
      resolvePlatform: () => TargetPlatform.android,
    );

    await repository.registerDeviceToken();

    verify(
      () => notificationsApi.registerPushToken(
        token: 'installation-123',
        platform: 'android',
      ),
    ).called(1);
  });

  test('iOS envia platform:"ios"', () async {
    final repository = NotificationsRepositoryImpl(
      notificationsApi,
      installationIdStorage,
      const FailureMapper(),
      resolvePlatform: () => TargetPlatform.iOS,
    );

    await repository.registerDeviceToken();

    verify(
      () => notificationsApi.registerPushToken(
        token: 'installation-123',
        platform: 'ios',
      ),
    ).called(1);
  });

  test(
    'plataforma fora de ios/android não envia nada — backend rejeitaria com 400',
    () async {
      final repository = NotificationsRepositoryImpl(
        notificationsApi,
        installationIdStorage,
        const FailureMapper(),
        resolvePlatform: () => TargetPlatform.windows,
      );

      await repository.registerDeviceToken();

      verifyNever(
        () => notificationsApi.registerPushToken(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
        ),
      );
    },
  );
}
