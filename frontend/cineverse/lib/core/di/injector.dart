import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/auth_api.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/catalog/data/catalog_api.dart';
import '../../features/catalog/data/repositories/catalog_repository_impl.dart';
import '../../features/catalog/domain/catalog_repository.dart';
import '../../features/catalog/presentation/bloc/catalog_bloc.dart';
import '../../features/chat/data/chat_api.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/chat_repository.dart';
import '../../features/chat/presentation/bloc/chat_room_bloc.dart';
import '../../features/chat/presentation/bloc/chat_rooms_bloc.dart';
import '../../features/chat/presentation/cubit/start_chat_cubit.dart';
import '../../features/feed/data/feed_api.dart';
import '../../features/feed/data/repositories/feed_repository_impl.dart';
import '../../features/feed/domain/feed_repository.dart';
import '../../features/feed/presentation/bloc/feed_bloc.dart';
import '../../features/feed/presentation/cubit/review_composer_cubit.dart';
import '../../features/notifications/data/notifications_api.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/notifications_repository.dart';
import '../../features/notifications/presentation/cubit/push_token_cubit.dart';
import '../../features/orders/data/orders_api.dart';
import '../../features/orders/data/repositories/orders_repository_impl.dart';
import '../../features/orders/domain/orders_repository.dart';
import '../../features/orders/presentation/bloc/checkout_bloc.dart';
import '../../features/payments/data/payments_api.dart';
import '../../features/payments/data/repositories/payments_repository_impl.dart';
import '../../features/payments/domain/payments_repository.dart';
import '../../features/payments/presentation/bloc/payment_bloc.dart';
import '../../features/profile/data/profile_api.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/profile_repository.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/seats/data/repositories/seats_repository_impl.dart';
import '../../features/tickets/data/repositories/tickets_repository_impl.dart';
import '../../features/tickets/data/tickets_api.dart';
import '../../features/tickets/domain/tickets_repository.dart';
import '../../features/tickets/presentation/bloc/ticket_scanner_bloc.dart';
import '../../features/seats/data/seats_api.dart';
import '../../features/seats/domain/seats_repository.dart';
import '../../features/seats/presentation/bloc/seat_map_bloc.dart';
import '../../features/sessions/data/repositories/sessions_repository_impl.dart';
import '../../features/sessions/data/sessions_api.dart';
import '../../features/sessions/domain/sessions_repository.dart';
import '../../features/sessions/presentation/bloc/nearby_sessions_bloc.dart';
import '../api/api_client.dart';
import '../api/auth_interceptor.dart';
import '../auth/session_expiry_notifier.dart';
import '../error/failure_mapper.dart';
import '../location/location_service.dart';
import '../storage/installation_id_storage.dart';
import '../storage/token_storage.dart';
import '../ws/socket_factory.dart';

final getIt = GetIt.instance;

/// Registro manual em três blocos: `singleton` (infraestrutura),
/// `lazySingleton` (repositórios) e `factory` (Blocs — nunca singleton, um
/// por instância de tela). Chamado uma única vez em `main.dart`.
void setupDependencies() {
  // Infraestrutura
  getIt
    ..registerSingleton<SessionExpiryNotifier>(SessionExpiryNotifier())
    ..registerSingleton<FailureMapper>(const FailureMapper())
    // `encryptedSharedPreferences: true` evita o backend legado baseado
    // direto no Android Keystore, que trava (`KEY_USER_NOT_AUTHENTICATED`)
    // em alguns aparelhos/versões de Android — confirmado num Galaxy S21
    // com Android 15 durante o desenvolvimento. É a mitigação documentada
    // do próprio pacote `flutter_secure_storage`.
    ..registerSingleton<FlutterSecureStorage>(
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
    )
    ..registerSingleton<TokenStorage>(TokenStorage(getIt()))
    ..registerSingleton<InstallationIdStorage>(InstallationIdStorage(getIt()))
    ..registerSingleton<AuthInterceptor>(AuthInterceptor(getIt(), getIt()))
    ..registerSingleton<ApiClient>(ApiClient(getIt()))
    ..registerSingleton<SocketFactory>(SocketFactory(getIt()));

  // features/auth — único Bloc global do app, ver app.dart
  getIt
    ..registerSingleton<AuthApi>(AuthApi(getIt()))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt(), getIt(), getIt()),
    )
    ..registerSingleton<AuthBloc>(AuthBloc(getIt(), getIt()));

  // features/catalog
  getIt
    ..registerSingleton<CatalogApi>(CatalogApi(getIt()))
    ..registerLazySingleton<CatalogRepository>(
      () => CatalogRepositoryImpl(getIt(), getIt()),
    )
    ..registerFactory<CatalogBloc>(() => CatalogBloc(getIt()));

  // features/sessions
  getIt
    ..registerSingleton<LocationService>(LocationService())
    ..registerSingleton<SessionsApi>(SessionsApi(getIt()))
    ..registerLazySingleton<SessionsRepository>(
      () => SessionsRepositoryImpl(getIt(), getIt(), getIt()),
    )
    ..registerFactory<NearbySessionsBloc>(
      () => NearbySessionsBloc(getIt(), getIt()),
    );

  // features/feed
  getIt
    ..registerSingleton<FeedApi>(FeedApi(getIt()))
    ..registerLazySingleton<FeedRepository>(
      () => FeedRepositoryImpl(getIt(), getIt(), getIt()),
    )
    ..registerFactory<FeedBloc>(() => FeedBloc(getIt()))
    ..registerFactory<ReviewComposerCubit>(() => ReviewComposerCubit(getIt()));

  // features/chat
  getIt
    ..registerSingleton<ChatApi>(ChatApi(getIt()))
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(getIt(), getIt()),
    )
    ..registerFactory<ChatRoomsBloc>(() => ChatRoomsBloc(getIt()))
    ..registerFactory<ChatRoomBloc>(
      () => ChatRoomBloc(getIt(), getIt(), getIt()),
    )
    ..registerFactory<StartChatCubit>(() => StartChatCubit(getIt()));

  // features/seats
  getIt
    ..registerSingleton<SeatsApi>(SeatsApi(getIt()))
    ..registerLazySingleton<SeatsRepository>(
      () => SeatsRepositoryImpl(getIt(), getIt()),
    )
    ..registerFactory<SeatMapBloc>(
      () => SeatMapBloc(getIt(), getIt(), getIt()),
    );

  // features/orders
  getIt
    ..registerSingleton<OrdersApi>(OrdersApi(getIt()))
    ..registerLazySingleton<OrdersRepository>(
      () => OrdersRepositoryImpl(getIt(), getIt()),
    )
    ..registerFactory<CheckoutBloc>(() => CheckoutBloc(getIt(), getIt()));

  // features/payments
  getIt
    ..registerSingleton<PaymentsApi>(PaymentsApi(getIt()))
    ..registerLazySingleton<PaymentsRepository>(
      () => PaymentsRepositoryImpl(getIt(), getIt()),
    )
    ..registerFactoryParam<PaymentBloc, int, void>(
      (orderId, _) => PaymentBloc(getIt(), orderId),
    );

  // features/tickets
  getIt
    ..registerSingleton<TicketsApi>(TicketsApi(getIt()))
    ..registerLazySingleton<TicketsRepository>(
      () => TicketsRepositoryImpl(getIt(), getIt()),
    )
    ..registerFactory<TicketScannerBloc>(() => TicketScannerBloc(getIt()));

  // features/notifications — Cubit de bootstrap, um só por sessão do app
  // (ver app.dart), nunca por tela.
  getIt
    ..registerSingleton<NotificationsApi>(NotificationsApi(getIt()))
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(getIt(), getIt(), getIt()),
    )
    ..registerLazySingleton<PushTokenCubit>(() => PushTokenCubit(getIt()));

  // features/profile
  getIt
    ..registerSingleton<ProfileApi>(ProfileApi(getIt()))
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(getIt(), getIt(), getIt()),
    )
    ..registerFactory<ProfileBloc>(() => ProfileBloc(getIt()));
}
