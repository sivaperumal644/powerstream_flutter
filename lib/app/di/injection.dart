import 'package:get_it/get_it.dart';
import 'package:powerstream_flutter/features/ble/data/datasources/ble_data_source.dart';
import 'package:powerstream_flutter/features/ble/data/datasources/ble_data_source_impl.dart';
import 'package:powerstream_flutter/features/ble/data/repositories/ble_instrument_repository.dart';
import 'package:powerstream_flutter/features/ble/domain/repositories/instrument_repository.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/connect_to_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/disconnect_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/find_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/start_streaming.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/stop_streaming.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/watch_instrument_events.dart';
import 'package:powerstream_flutter/features/ble/presentation/bloc/instrument_connection_bloc.dart';

final getIt = GetIt.instance;

// Each feature registration stays here.
Future<void> configureDependencies() async {
  _registerBle();
}

void _registerBle() {
  getIt.registerLazySingleton<BleDataSource>(
    () => BleDataSourceImpl(),
    dispose: (ds) => ds.dispose(),
  );

  getIt.registerLazySingleton<InstrumentRepository>(
    () => BleInstrumentRepository(getIt()),
    dispose: (repo) => repo.dispose(),
  );

  getIt
    ..registerFactory(() => ConnectToInstrument(getIt()))
    ..registerFactory(() => DisconnectInstrument(getIt()))
    ..registerFactory(() => FindInstrument(getIt()))
    ..registerFactory(() => StartStreaming(getIt()))
    ..registerFactory(() => StopStreaming(getIt()))
    ..registerFactory(() => WatchInstrumentEvents(getIt()));

  getIt.registerFactory(
    () => InstrumentConnectionBloc(
      findInstrument: getIt(),
      connectToInstrument: getIt(),
      startStreaming: getIt(),
      stopStreaming: getIt(),
      disconnectInstrument: getIt(),
      watchInstrumentEvents: getIt(),
    ),
  );
}
