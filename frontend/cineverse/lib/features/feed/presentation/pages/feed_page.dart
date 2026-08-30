import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/feed_entry.dart';
import '../bloc/feed_bloc.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<FeedBloc>().add(const FeedRequested());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      context.read<FeedBloc>().add(const FeedNextPageRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF6E37B3),
          foregroundColor: Colors.white,
          onPressed: () => context.push('/feed/new'),
          child: const Icon(Icons.edit_outlined),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  children: [
                    AppLogo(height: 56),
                    SizedBox(height: 16),
                    Text(
                      'Resenhas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocConsumer<FeedBloc, FeedState>(
                  listenWhen: (previous, current) =>
                      previous.pendingShare != current.pendingShare,
                  listener: (context, state) {
                    final share = state.pendingShare;
                    if (share != null) {
                      Share.share(
                        '${share.text}\n${share.url}',
                        subject: share.title,
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state.status == StateStatus.initial ||
                        (state.status == StateStatus.loading &&
                            state.entries.isEmpty)) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.status == StateStatus.failure &&
                        state.entries.isEmpty) {
                      return AppErrorView(
                        failure: state.failure!,
                        onRetry: () =>
                            context.read<FeedBloc>().add(const FeedRequested()),
                      );
                    }
                    if (state.entries.isEmpty) {
                      return const EmptyState(
                        message: 'Ainda não há resenhas por aqui.',
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      itemCount:
                          state.entries.length + (state.hasReachedMax ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index >= state.entries.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final entry = state.entries[index];
                        final revealedText = state.revealedTexts[entry.review.id];
                        return _ReviewCard(entry: entry, revealedText: revealedText);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.entry, required this.revealedText});

  final FeedEntry entry;
  final String? revealedText;

  static const _shape = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    final review = entry.review;
    final movie = entry.movie;
    final isRevealed = revealedText != null || !review.hasSpoiler;
    final displayText = revealedText ?? review.text;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: _shape,
        border: Border.all(color: const Color(0xFF6E37B3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 68,
                  child: movie?.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: movie!.posterUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const ColoredBox(color: Colors.black26),
                          errorWidget: (context, url, error) =>
                              const ColoredBox(
                                color: Colors.black26,
                                child: Icon(
                                  Icons.movie_outlined,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                              ),
                        )
                      : const ColoredBox(
                          color: Colors.black26,
                          child: Icon(
                            Icons.movie_outlined,
                            color: Colors.white38,
                            size: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie?.title ?? 'Filme #${review.movieId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cinéfilo #${review.userId}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          size: 15,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isRevealed)
            Text(
              displayText ?? '',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta resenha contém spoiler.',
                  style: TextStyle(color: Colors.white54),
                ),
                TextButton(
                  onPressed: () => context.read<FeedBloc>().add(
                    ReviewRevealRequested(review.id),
                  ),
                  child: const Text('Revelar'),
                ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                color: const Color(0xFFB98CF2),
                tooltip: 'Conversar com o autor',
                onPressed: () => context.push('/chat/start/${review.userId}'),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                color: Colors.white54,
                onPressed: () => context.read<FeedBloc>().add(
                  ReviewShareRequested(review.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
