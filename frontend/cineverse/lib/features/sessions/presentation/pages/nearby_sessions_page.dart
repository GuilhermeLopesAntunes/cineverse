import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../seats/presentation/pages/seat_map_page.dart';
import '../../domain/entities/session_with_movie.dart';
import '../bloc/nearby_sessions_bloc.dart';
import '../nearby_sessions_filter.dart';

class NearbySessionsPage extends StatefulWidget {
  const NearbySessionsPage({super.key, this.filter});

  final NearbySessionsFilter? filter;

  @override
  State<NearbySessionsPage> createState() => _NearbySessionsPageState();
}

class _NearbySessionsPageState extends State<NearbySessionsPage> {
  /// Começa mostrando só as sessões do filme (quando há filtro); o usuário
  /// pode escolher ver todas as sessões daquele cinema também.
  bool _showAllSessions = false;

  @override
  void initState() {
    super.initState();
    context.read<NearbySessionsBloc>().add(const NearbySessionsRequested());
  }

  String _locationIssueMessage(LocationIssue issue) {
    return switch (issue) {
      LocationIssue.permissionDenied =>
        'Precisamos da sua localização para encontrar o cinema mais próximo.',
      LocationIssue.permissionDeniedForever =>
        'Permissão de localização negada. Abra as configurações do app para conceder.',
      LocationIssue.serviceDisabled =>
        'Ative a localização do dispositivo para continuar.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  children: [
                    const AppLogo(height: 56),
                    const SizedBox(height: 16),
                    Text(
                      widget.filter == null
                          ? 'Cinema mais próximo'
                          : 'Sessões de ${widget.filter!.movieTitle}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<NearbySessionsBloc, NearbySessionsState>(
                  builder: (context, state) => _Body(
                    state: state,
                    filter: widget.filter,
                    showAllSessions: _showAllSessions,
                    onToggleShowAll: () =>
                        setState(() => _showAllSessions = !_showAllSessions),
                    onRetry: () => context.read<NearbySessionsBloc>().add(
                      const NearbySessionsRequested(),
                    ),
                    locationIssueMessage: _locationIssueMessage,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.filter,
    required this.showAllSessions,
    required this.onToggleShowAll,
    required this.onRetry,
    required this.locationIssueMessage,
  });

  final NearbySessionsState state;
  final NearbySessionsFilter? filter;
  final bool showAllSessions;
  final VoidCallback onToggleShowAll;
  final VoidCallback onRetry;
  final String Function(LocationIssue) locationIssueMessage;

  @override
  Widget build(BuildContext context) {
    if (state.status == StateStatus.initial ||
        state.status == StateStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.locationIssue != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 48,
                color: Colors.white54,
              ),
              const SizedBox(height: 12),
              Text(
                locationIssueMessage(state.locationIssue!),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              GradientButton(
                onPressed:
                    state.locationIssue == LocationIssue.permissionDeniedForever
                    ? () => getIt<LocationService>().openSettings()
                    : onRetry,
                child: Text(
                  state.locationIssue == LocationIssue.permissionDeniedForever
                      ? 'Abrir configurações'
                      : 'Tentar de novo',
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (state.status == StateStatus.failure) {
      return AppErrorView(failure: state.failure!, onRetry: onRetry);
    }
    if (state.partner == null || state.sessions.isEmpty) {
      return const EmptyState(
        message: 'Nenhum cinema parceiro cadastrado perto de você.',
        icon: Icons.local_movies_outlined,
      );
    }

    final partner = state.partner!;
    final showingFiltered = filter != null && !showAllSessions;
    final sessions = showingFiltered
        ? state.sessions.where((s) => s.session.movieId == filter!.movieId).toList()
        : state.sessions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            const Icon(
              Icons.location_on,
              color: Color(0xFF6E37B3),
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                partner.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${partner.distanceKm.toStringAsFixed(1)} km',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (showingFiltered && sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhuma sessão de "${filter!.movieTitle}" neste cinema agora.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onToggleShowAll,
                  child: const Text('Ver todas as sessões deste cinema'),
                ),
              ],
            ),
          )
        else ...[
          if (filter != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                onPressed: onToggleShowAll,
                child: Text(
                  showAllSessions
                      ? 'Mostrar só sessões de "${filter!.movieTitle}"'
                      : 'Ver todas as sessões deste cinema',
                ),
              ),
            ),
          for (final item in sessions)
            _SessionCard(item: item, partnerId: partner.id),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item, required this.partnerId});

  final SessionWithMovie item;
  final int partnerId;

  // Mesma linguagem visual dos cards do catálogo — cantos arredondados
  // menos o superior direito, borda roxa.
  static const _shape = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    final session = item.session;
    final movie = item.movie;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: _shape,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E37B3).withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.black,
        clipBehavior: Clip.antiAlias,
        borderRadius: _shape,
        child: InkWell(
          onTap: () => context.push(
            '/nearby/sessions/${session.id}/seats',
            extra: SeatMapArgs(
              sessionId: session.id,
              partnerId: partnerId,
              priceCents: session.priceCents,
              movieId: session.movieId,
              sessionDatetime: session.datetime,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: _shape,
              border: Border.all(color: const Color(0xFF6E37B3), width: 2),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 76,
                    child: movie?.posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: movie!.posterUrl!,
                            fit: BoxFit.cover,
                          )
                        : const ColoredBox(
                            color: Colors.black26,
                            child: Icon(
                              Icons.movie_outlined,
                              color: Colors.white38,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie?.title ?? 'Sessão',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Formatters.date(session.datetime)} · ${Formatters.time(session.datetime)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.money(session.priceCents),
                        style: const TextStyle(
                          color: Color(0xFFB98CF2),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
