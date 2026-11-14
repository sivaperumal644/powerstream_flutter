import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powerstream_flutter/app/app.dart';
import 'package:powerstream_flutter/app/app_bloc_observer.dart';
import 'package:powerstream_flutter/app/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  Bloc.observer = AppBlocObserver();
  runApp(const PowerStreamApp());
}
