import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../bloc/auth_bloc.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../widgets/auth_scaffold.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/branded_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Informe seu e-mail';
    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return isValid ? null : 'E-mail inválido';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 8) {
      return 'A senha deve ter no mínimo 8 caracteres';
    }
    // O backend limita a 72 porque o bcrypt trunca acima disso.
    if (value.length > 72) return 'A senha deve ter no máximo 72 caracteres';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return 'As senhas não coincidem';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: name.isEmpty ? null : name,
      ),
    );
  }

  String _failureMessage(Failure failure) {
    return switch (failure) {
      ConflictFailure(:final message) => message,
      NetworkFailure() => 'Sem conexão. Verifique sua internet.',
      _ => 'Não foi possível criar a conta. Tente novamente.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current.actionStatus == AuthActionStatus.failure,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_failureMessage(state.failure!))),
          );
        },
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(),
              const SizedBox(height: 32),
              const Text(
                'Criar conta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Preencha os dados abaixo para começar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 40),
              BrandedTextField(
                controller: _nameController,
                labelText: 'Nome',
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 20),
              BrandedTextField(
                controller: _emailController,
                labelText: 'E-mail',
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                prefixIcon: Icons.mail_outline,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 20),
              BrandedTextField(
                controller: _passwordController,
                labelText: 'Senha',
                obscureText: true,
                helperText: 'Entre 8 e 72 caracteres',
                validator: _validatePassword,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 20),
              BrandedTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirmar senha',
                obscureText: true,
                validator: _validateConfirmPassword,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SecondaryButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Voltar'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isSubmitting =
                              state.actionStatus ==
                              AuthActionStatus.submitting;
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
                                : const Text('Criar conta'),
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
    );
  }
}
