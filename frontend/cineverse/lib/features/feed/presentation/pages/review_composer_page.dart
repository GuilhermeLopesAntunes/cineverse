import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/branded_text_field.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../catalog/domain/entities/movie.dart';
import '../cubit/review_composer_cubit.dart';

/// Escolha de filme vem do catálogo (via `extra` da navegação) — não existe
/// busca de filme dentro do compositor, só o que já está em cache.
class ReviewComposerPage extends StatefulWidget {
  const ReviewComposerPage({super.key, required this.movie});

  final Movie movie;

  @override
  State<ReviewComposerPage> createState() => _ReviewComposerPageState();
}

class _ReviewComposerPageState extends State<ReviewComposerPage> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  int _rating = 5;
  bool _hasSpoiler = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ReviewComposerCubit>().submit(
      movieId: widget.movie.id,
      text: _textController.text,
      rating: _rating,
      hasSpoiler: _hasSpoiler,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        body: SafeArea(
          child: BlocListener<ReviewComposerCubit, ReviewComposerState>(
            listener: (context, state) {
              if (state.status == ReviewComposerStatus.success) {
                context.pop();
              }
              if (state.status == ReviewComposerStatus.failure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Não foi possível publicar a resenha. Tente de novo.',
                    ),
                  ),
                );
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Escrever resenha',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 68,
                        child: widget.movie.posterUrl != null
                            ? CachedNetworkImage(
                                imageUrl: widget.movie.posterUrl!,
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
                      child: Text(
                        widget.movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sua nota',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => IconButton(
                            icon: Icon(
                              i < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 28,
                            ),
                            onPressed: () => setState(() => _rating = i + 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      BrandedTextField(
                        controller: _textController,
                        labelText: 'Sua resenha',
                        maxLines: 6,
                        maxLength: 2000,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Escreva sua resenha'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Contém spoiler',
                          style: TextStyle(color: Colors.white),
                        ),
                        activeThumbColor: const Color(0xFF6E37B3),
                        value: _hasSpoiler,
                        onChanged: (value) =>
                            setState(() => _hasSpoiler = value),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: BlocBuilder<ReviewComposerCubit, ReviewComposerState>(
                          builder: (context, state) {
                            final isSubmitting =
                                state.status == ReviewComposerStatus.submitting;
                            return GradientButton(
                              onPressed: isSubmitting ? null : _submit,
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Publicar'),
                            );
                          },
                        ),
                      ),
                    ],
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
