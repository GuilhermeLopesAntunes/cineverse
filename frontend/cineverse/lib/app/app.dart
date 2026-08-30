import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injector.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/notifications/presentation/cubit/push_token_cubit.dart';
import 'router.dart';
import 'theme.dart';

class CineverseApp extends StatelessWidget {
  const CineverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: getIt<AuthBloc>(),
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            previous.sessionStatus != SessionStatus.authenticated &&
            current.sessionStatus == SessionStatus.authenticated,
        listener: (context, state) => getIt<PushTokenCubit>().register(),
        child: Builder(
          builder: (context) {
            final router = buildRouter(context.read<AuthBloc>());
            return MaterialApp.router(
              title: 'CineVerse',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}
