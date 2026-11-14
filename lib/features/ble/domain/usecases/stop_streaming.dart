import 'package:powerstream_flutter/features/ble/domain/repositories/instrument_repository.dart';

class StopStreaming {
  final InstrumentRepository _repository;
  const StopStreaming(this._repository);

  Future<void> call() async => await _repository.stop();
}
