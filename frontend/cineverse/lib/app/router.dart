import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injector.dart';
import '../core/widgets/placeholder_page.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/catalog/domain/entities/movie.dart';
import '../features/catalog/presentation/bloc/catalog_bloc.dart';
import '../features/catalog/presentation/pages/catalog_page.dart';
import '../features/catalog/presentation/pages/movie_detail_page.dart';
import '../features/chat/presentation/bloc/chat_room_bloc.dart';
import '../features/chat/presentation/bloc/chat_rooms_bloc.dart';
import '../features/chat/presentation/cubit/start_chat_cubit.dart';
import '../features/chat/presentation/pages/chat_room_page.dart';
import '../features/chat/presentation/pages/chat_rooms_page.dart';
import '../features/chat/presentation/pages/start_chat_page.dart';
import '../features/feed/presentation/bloc/feed_bloc.dart';
import '../features/feed/presentation/cubit/review_composer_cubit.dart';
import '../features/feed/presentation/pages/feed_page.dart';
import '../features/feed/presentation/pages/review_composer_page.dart';
import '../features/orders/presentation/bloc/checkout_bloc.dart';
import '../features/orders/presentation/checkout_args.dart';
import '../features/orders/presentation/pages/checkout_page.dart';
import '../features/orders/presentation/pages/order_confirmation_page.dart';
import '../features/payments/presentation/bloc/payment_bloc.dart';
import '../features/payments/presentation/pages/payment_page.dart';
import '../features/payments/presentation/payment_args.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/seats/presentation/bloc/seat_map_bloc.dart';
import '../features/seats/presentation/pages/seat_map_page.dart';
import '../features/sessions/presentation/bloc/nearby_sessions_bloc.dart';
import '../features/sessions/presentation/nearby_sessions_filter.dart';
import '../features/sessions/presentation/pages/nearby_sessions_page.dart';
import '../features/tickets/presentation/bloc/ticket_scanner_bloc.dart';
import '../features/tickets/presentation/pages/ticket_scanner_page.dart';
import '../features/tickets/presentation/pages/ticket_unavailable_page.dart';

/// Adapta o `Stream<AuthState>` do `AuthBloc` para o `Listenable` que
/// `go_router` espera em `refreshListenable`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// `/splash` não entra aqui de propósito: uma vez que a sessão deixa de ser
// `unknown`, a splash sempre precisa redirecionar para algum lugar — nunca
// é um destino válido por si só (diferente de /login e /register, que o
// usuário pode legitimamente ficar vendo enquanto anônimo).
const _publicPaths = ['/login', '/register'];

/// Função pura para poder testar todas as combinações de
/// `sessionStatus`/`location` sem precisar montar um `GoRouter` de verdade —
/// foi exatamente a falta disso que deixou passar um bug em que `/splash`
/// contava como "caminho público" e o app nunca saía dela quando a sessão
/// virava `anonymous`.
String? computeAuthRedirect({
  required SessionStatus sessionStatus,
  required String location,
}) {
  final isPublicPath = _publicPaths.contains(location);

  if (sessionStatus == SessionStatus.unknown) {
    return location == '/splash' ? null : '/splash';
  }
  if (sessionStatus == SessionStatus.anonymous) {
    return isPublicPath ? null : '/login';
  }
  // authenticated
  if (location == '/splash' || isPublicPath) return '/catalog';
  return null;
}

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) => computeAuthRedirect(
      sessionStatus: authBloc.state.sessionStatus,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/catalog',
            builder: (context, state) => BlocProvider(
              create: (_) => getIt<CatalogBloc>(),
              child: const CatalogPage(),
            ),
            routes: [
              GoRoute(
                path: ':movieId',
                builder: (context, state) {
                  final movie = state.extra;
                  if (movie is! Movie) {
                    return const PlaceholderPage(
                      title: 'Detalhe do filme',
                      details: 'Abra o filme a partir da lista do catálogo.',
                    );
                  }
                  return MovieDetailPage(movie: movie);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/nearby',
            builder: (context, state) => BlocProvider(
              create: (_) => getIt<NearbySessionsBloc>(),
              child: NearbySessionsPage(
                filter: state.extra as NearbySessionsFilter?,
              ),
            ),
            routes: [
              GoRoute(
                path: 'sessions/:sessionId/seats',
                builder: (context, state) {
                  final args = state.extra;
                  if (args is! SeatMapArgs) {
                    return const PlaceholderPage(
                      title: 'Mapa de assentos',
                      details: 'Abra a partir da lista de sessões próximas.',
                    );
                  }
                  return BlocProvider(
                    create: (_) => getIt<SeatMapBloc>(),
                    child: SeatMapPage(args: args),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'checkout',
                    builder: (context, state) {
                      final args = state.extra;
                      if (args is! CheckoutArgs) {
                        return const PlaceholderPage(
                          title: 'Checkout',
                          details: 'Abra a partir do mapa de assentos.',
                        );
                      }
                      return BlocProvider(
                        create: (_) => getIt<CheckoutBloc>(),
                        child: CheckoutPage(args: args),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'payment',
                        builder: (context, state) {
                          final args = state.extra;
                          if (args is! PaymentArgs) {
                            return const PlaceholderPage(
                              title: 'Pagamento',
                              details:
                                  'Abra a partir da confirmação do pedido.',
                            );
                          }
                          return BlocProvider(
                            create: (_) =>
                                getIt<PaymentBloc>(param1: args.order.id),
                            child: PaymentPage(args: args),
                          );
                        },
                        routes: [
                          GoRoute(
                            path: 'success',
                            builder: (context, state) {
                              final args = state.extra;
                              if (args is! PaymentArgs) {
                                return const PlaceholderPage(
                                  title: 'Confirmação de compra',
                                  details: 'Abra a partir do pagamento.',
                                );
                              }
                              return OrderConfirmationPage(args: args);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/feed',
            builder: (context, state) => BlocProvider(
              create: (_) => getIt<FeedBloc>(),
              child: const FeedPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) {
                  final movie = state.extra;
                  if (movie is! Movie) {
                    return const PlaceholderPage(
                      title: 'Publicar resenha',
                      details: 'Abra a partir do detalhe de um filme.',
                    );
                  }
                  return BlocProvider(
                    create: (_) => getIt<ReviewComposerCubit>(),
                    child: ReviewComposerPage(movie: movie),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => BlocProvider(
              create: (_) => getIt<ProfileBloc>(),
              child: const ProfilePage(),
            ),
            routes: [
              GoRoute(
                path: 'orders',
                builder: (context, state) =>
                    const PlaceholderPage(title: 'Meus pedidos'),
                routes: [
                  GoRoute(
                    path: ':orderId',
                    builder: (context, state) => PlaceholderPage(
                      title: 'Detalhe do pedido',
                      details: 'orderId=${state.pathParameters['orderId']}',
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'scanner',
                builder: (context, state) => BlocProvider(
                  create: (_) => getIt<TicketScannerBloc>(),
                  child: const TicketScannerPage(),
                ),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/ticket',
        builder: (context, state) => const TicketUnavailablePage(),
      ),

      GoRoute(
        path: '/chat',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<ChatRoomsBloc>(),
          child: const ChatRoomsPage(),
        ),
        routes: [
          GoRoute(
            path: 'start/:authorId',
            builder: (context, state) {
              final authorId = int.parse(state.pathParameters['authorId']!);
              return BlocProvider(
                create: (_) => getIt<StartChatCubit>(),
                child: StartChatPage(authorId: authorId),
              );
            },
          ),
          GoRoute(
            path: ':roomId',
            builder: (context, state) {
              final roomId = int.parse(state.pathParameters['roomId']!);
              return BlocProvider(
                create: (_) => getIt<ChatRoomBloc>(),
                child: ChatRoomPage(roomId: roomId),
              );
            },
          ),
        ],
      ),
    ],
  );
}

/// Shell com barra inferior de 4 abas (ARQUITETURA_FRONTEND.md § 6).
class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = ['/catalog', '/nearby', '/feed', '/profile'];

  static const _items = [
    _NavItem(icon: Icons.movie_outlined, label: 'Catálogo'),
    _NavItem(icon: Icons.place_outlined, label: 'Próximo'),
    _NavItem(icon: Icons.rate_review_outlined, label: 'Feed'),
    _NavItem(icon: Icons.person_outline, label: 'Perfil'),
  ];

  int get _currentIndex {
    final index = _tabs.indexWhere((tab) => location.startsWith(tab));
    return index == -1 ? 0 : index;
  }

  // Altura da barra + a margem inferior que a `SafeArea` abaixo aplica
  // entre ela e a borda da tela.
  static const _navBarHeight = 64.0;
  static const _navBarBottomMargin = 12.0;

  @override
  Widget build(BuildContext context) {
    // Reservado explicitamente com `Padding` em vez de depender de
    // `Scaffold.extendBody` + `MediaQuery.padding` — cada página abaixo
    // (`CatalogPage`, `MovieDetailPage`, checkout, etc.) monta seu próprio
    // `Scaffold`/`CustomScrollView` sem necessariamente consumir esse
    // `MediaQuery` ajustado, e o botão no fim da tela ficava escondido atrás
    // da navbar flutuante. Reservando o espaço aqui, uma vez só, nenhuma
    // página precisa saber que a navbar existe.
    final bottomSystemInset = MediaQuery.of(context).padding.bottom;
    final reservedHeight =
        _navBarHeight + _navBarBottomMargin + bottomSystemInset;

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: reservedHeight),
            child: child,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: _navBarBottomMargin + bottomSystemInset,
            child: _FloatingNavBar(
              currentIndex: _currentIndex,
              items: _items,
              onTap: (index) => context.go(_tabs[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Navbar flutuante da marca: fundo em gradiente roxo, cantos arredondados
/// e a aba ativa marcada por um fundo circular branco atrás do ícone — em
/// vez do `NavigationBar` Material padrão.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF8038DE), Color(0xFF622BAB), Color(0xFF451E78)],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: _gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _FloatingNavBarItem(
                item: items[i],
                isSelected: i == currentIndex,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingNavBarItem extends StatelessWidget {
  const _FloatingNavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  static const _selectedColor = Color(0xFF622BAB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Semantics(
          label: item.label,
          selected: isSelected,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : Colors.transparent,
              ),
              child: Icon(
                item.icon,
                color: isSelected ? _selectedColor : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
