import 'package:flutter/material.dart';
import 'package:powerstream_flutter/app/app.dart';
import 'package:powerstream_flutter/app/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const PowerStreamApp());
}
