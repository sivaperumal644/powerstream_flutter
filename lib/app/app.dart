import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powerstream_flutter/app/di/injection.dart';
import 'package:powerstream_flutter/features/ble/presentation/bloc/instrument_connection_bloc.dart';
import 'package:powerstream_flutter/features/ble/presentation/device_page.dart';

class PowerStreamApp extends StatelessWidget {
  const PowerStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<InstrumentConnectionBloc>(),
      child: MaterialApp(
        title: 'Power Stream App',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const DevicePage(),
      ),
    );
  }
}
