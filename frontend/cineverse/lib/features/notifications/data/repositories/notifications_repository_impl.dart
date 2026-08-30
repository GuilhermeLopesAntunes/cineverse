import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/storage/installation_id_storage.dart';
import '../../domain/notifications_repository.dart';
import '../notifications_api.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(
    this._notificationsApi,
    this._installationIdStorage,
    this._failureMapper, {
    TargetPlatform Function()? resolvePlatform,
  }) : _resolvePlatform = resolvePlatform ?? (() => defaultTargetPlatform);

  final NotificationsApi _notificationsApi;
  final InstallationIdStorage _installationIdStorage;
  final FailureMapper _failureMapper;
  final TargetPlatform Function() _resolvePlatform;

  @override
  Future<void> registerDeviceToken() async {
    final platform = switch (_resolvePlatform()) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    if (platform == null) return;

    try {
      final installationId = await _installationIdStorage.readOrCreate();
      await _notificationsApi.registerPushToken(
        token: installationId,
        platform: platform,
      );
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }
}
