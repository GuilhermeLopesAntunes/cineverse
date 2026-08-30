import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/bloc_observer.dart';
import 'core/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Bloc.observer = AppBlocObserver();
  setupDependencies();
  runApp(const CineverseApp());
}
