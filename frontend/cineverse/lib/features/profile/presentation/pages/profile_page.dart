import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/genres.dart';
import '../bloc/profile_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const ProfileRequested());
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.dark,
        child: AlertDialog(
          backgroundColor: const Color(0xFF15102A),
          title: const Text('Sair da conta?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Você vai precisar entrar de novo para continuar usando o app.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Sair',
                style: TextStyle(color: Color(0xFFE9666A)),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
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
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  children: [
                    AppLogo(height: 56),
                    SizedBox(height: 16),
                    Text(
                      'Perfil',
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
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    if (state.status == StateStatus.initial ||
                        state.status == StateStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.status == StateStatus.failure) {
                      return AppErrorView(
                        failure: state.failure!,
                        onRetry: () => context.read<ProfileBloc>().add(
                          const ProfileRequested(),
                        ),
                      );
                    }
                    return _ProfileBody(
                      state: state,
                      onLogout: () => _confirmLogout(context),
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

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.state, required this.onLogout});

  final ProfileState state;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6E37B3), Color(0xFF4E2086), Color(0xFF33145A)],
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            state.email ?? 'E-mail não disponível',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gêneros favoritos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.read<ProfileBloc>().add(const ProfileEditToggled()),
              child: Text(state.isEditing ? 'Cancelar' : 'Editar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.isEditing)
          _GenreEditor(state: state)
        else if (state.favoriteGenres.isEmpty)
          const Text(
            'Nenhum gênero favorito ainda.',
            style: TextStyle(color: Colors.white54),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final genre in state.favoriteGenres) _GenreChip(label: genre),
            ],
          ),
        if (state.isEditing) ...[
          const SizedBox(height: 16),
          if (state.saveStatus == SaveStatus.failure)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Não foi possível salvar. Tente de novo.',
                style: TextStyle(color: Color(0xFFE9666A)),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              onPressed: state.saveStatus == SaveStatus.saving
                  ? null
                  : () => context.read<ProfileBloc>().add(
                      const ProfileSaveRequested(),
                    ),
              child: state.saveStatus == SaveStatus.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ),
        ],
        const SizedBox(height: 40),
        const Divider(color: Colors.white24),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SecondaryButton(
            onPressed: onLogout,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout, size: 18, color: Color(0xFFE9666A)),
                SizedBox(width: 10),
                Text('Sair da conta', style: TextStyle(color: Color(0xFFE9666A))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6E37B3)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}

class _GenreEditor extends StatelessWidget {
  const _GenreEditor({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final genre in kAvailableGenres)
          GestureDetector(
            onTap: () => context.read<ProfileBloc>().add(
              ProfileGenreToggled(genre),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: state.selectedGenres.contains(genre)
                    ? const LinearGradient(
                        colors: [Color(0xFF6E37B3), Color(0xFF4E2086)],
                      )
                    : null,
                color: state.selectedGenres.contains(genre)
                    ? null
                    : Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: state.selectedGenres.contains(genre)
                      ? Colors.transparent
                      : Colors.white24,
                ),
              ),
              child: Text(
                genre,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}
