import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../sessions/presentation/nearby_sessions_filter.dart';
import '../../domain/entities/movie.dart';

/// Montada a partir do item já em cache — não existe `GET /catalog/movies/:id`.
/// O filme chega via `extra` da navegação (o item que o usuário já viu na
/// grade), nunca por uma nova requisição.
class MovieDetailPage extends StatelessWidget {
  const MovieDetailPage({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 440,
              backgroundColor: AppTheme.authBackground,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                titlePadding: const EdgeInsets.only(
                  left: 56,
                  right: 16,
                  bottom: 16,
                ),
                title: Text(
                  movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                background: _PosterHero(movie: movie),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SINOPSE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (movie.synopsis?.isNotEmpty ?? false)
                          ? movie.synopsis!
                          : 'Sinopse não disponível.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        onPressed: () => context.go(
                          '/nearby',
                          extra: NearbySessionsFilter(
                            movieId: movie.id,
                            movieTitle: movie.title,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_activity_outlined),
                            SizedBox(width: 10),
                            Text('Comprar ingresso'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton(
                        onPressed: () =>
                            context.push('/feed/new', extra: movie),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Escrever resenha'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pôster em largura total com um degradê na base que se funde com o fundo
/// escuro da página — é o que deixa o título (desenhado pelo
/// `FlexibleSpaceBar`) legível sem precisar de uma faixa sólida por trás.
class _PosterHero extends StatelessWidget {
  const _PosterHero({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (movie.posterUrl != null)
          CachedNetworkImage(
            imageUrl: movie.posterUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => const ColoredBox(
              color: Colors.black26,
            ),
            errorWidget: (context, url, error) => const _PosterFallback(),
          )
        else
          const _PosterFallback(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                AppTheme.authBackground.withValues(alpha: 0.55),
                AppTheme.authBackground,
              ],
              stops: const [0, 0.55, 0.85, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF451E78), Color(0xFF07081A)],
        ),
      ),
      child: Center(
        child: Icon(Icons.movie_outlined, size: 72, color: Colors.white38),
      ),
    );
  }
}
