import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/branded_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_category.dart';
import '../bloc/catalog_bloc.dart';

const _categories = [
  MovieCategory.emCartaz,
  MovieCategory.lancamento,
  MovieCategory.emBreve,
];

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _searchController = TextEditingController();
  final _pageController = PageController();
  int _categoryIndex = 0;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToCategory(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = _categories[_categoryIndex];
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Column(
                  children: [
                    const AppLogo(height: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Escolha seu filme',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BrandedTextField(
                      controller: _searchController,
                      labelText: 'Buscar filme',
                      prefixIcon: Icons.search,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      suffix: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CategoryArrowButton(
                          icon: Icons.chevron_left,
                          onPressed: _categoryIndex > 0
                              ? () => _goToCategory(_categoryIndex - 1)
                              : null,
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            category.label,
                            key: ValueKey(category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _CategoryArrowButton(
                          icon: Icons.chevron_right,
                          onPressed: _categoryIndex < _categories.length - 1
                              ? () => _goToCategory(_categoryIndex + 1)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _categories.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _categoryIndex ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i == _categoryIndex
                                  ? const Color(0xFF6E37B3)
                                  : Colors.white24,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _categoryIndex = index),
                  children: [
                    for (final category in _categories)
                      _CategoryGrid(
                        category: category,
                        searchQuery: _searchQuery,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryArrowButton extends StatelessWidget {
  const _CategoryArrowButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isEnabled ? const Color(0x336E37B3) : Colors.transparent,
        border: Border.all(
          color: isEnabled ? const Color(0xFF6E37B3) : Colors.white24,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: isEnabled ? Colors.white : Colors.white24,
      ),
    );
  }
}

class _CategoryGrid extends StatefulWidget {
  const _CategoryGrid({required this.category, required this.searchQuery});

  final MovieCategory category;
  final String searchQuery;

  @override
  State<_CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<_CategoryGrid>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<CatalogBloc>().add(CatalogCategoryRequested(widget.category));
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
      context.read<CatalogBloc>().add(
        CatalogNextPageRequested(widget.category),
      );
    }
  }

  List<Movie> _filtered(List<Movie> movies) {
    if (widget.searchQuery.isEmpty) return movies;
    final query = widget.searchQuery.toLowerCase();
    return movies.where((m) => m.title.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<CatalogBloc, CatalogState>(
      buildWhen: (previous, current) =>
          previous.feedOf(widget.category) != current.feedOf(widget.category),
      builder: (context, state) {
        final feed = state.feedOf(widget.category);

        if (feed.status == StateStatus.initial ||
            (feed.status == StateStatus.loading && feed.movies.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (feed.status == StateStatus.failure && feed.movies.isEmpty) {
          return AppErrorView(
            failure: feed.failure!,
            onRetry: () => context.read<CatalogBloc>().add(
              CatalogCategoryRequested(widget.category),
            ),
          );
        }

        final movies = _filtered(feed.movies);
        if (movies.isEmpty) {
          return EmptyState(
            message: widget.searchQuery.isNotEmpty
                ? 'Nenhum filme encontrado para "${widget.searchQuery}".'
                : 'Nenhum filme em ${widget.category.label.toLowerCase()} no momento.',
          );
        }

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount:
              movies.length +
              (feed.hasReachedMax || widget.searchQuery.isNotEmpty ? 0 : 1),
          itemBuilder: (context, index) {
            if (index >= movies.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final movie = movies[index];
            return _MovieCard(
              movie: movie,
              onTap: () => context.push('/catalog/${movie.id}', extra: movie),
            );
          },
        );
      },
    );
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  // Todos os cantos arredondados menos o superior direito, por pedido de
  // design — `Radius.zero` (o default de `BorderRadius.only`) nesse canto.
  static const _shape = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: _shape,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E37B3).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.black,
        clipBehavior: Clip.antiAlias,
        borderRadius: _shape,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: _shape,
              border: Border.all(color: const Color(0xFF6E37B3), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: movie.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: movie.posterUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) =>
                              const ColoredBox(color: Colors.black26),
                          errorWidget: (context, url, error) =>
                              const ColoredBox(
                                color: Colors.black26,
                                child: Icon(
                                  Icons.movie_outlined,
                                  size: 48,
                                  color: Colors.white54,
                                ),
                              ),
                        )
                      : const ColoredBox(
                          color: Colors.black26,
                          child: Center(
                            child: Icon(
                              Icons.movie_outlined,
                              size: 48,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  color: Colors.white.withValues(alpha: 0.06),
                  child: Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
