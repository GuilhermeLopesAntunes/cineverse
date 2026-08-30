import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'auth_interceptor.dart';

/// `Dio` configurado com a base `/api/v1` do backend. Repositórios recebem
/// esta instância (ou uma feature-api construída sobre ela) — nunca `dio`
/// cru fora de `core/api` e das `*_api.dart` de cada feature.
class ApiClient {
  ApiClient(AuthInterceptor authInterceptor)
    : dio = Dio(
        BaseOptions(
          baseUrl: '${AppConfig.apiBaseUrl}/api/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ) {
    dio.interceptors.add(authInterceptor);
  }

  final Dio dio;
}
