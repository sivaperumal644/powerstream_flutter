import 'package:powerstream_flutter/features/ble/domain/repositories/instrument_repository.dart';

class DisconnectInstrument {
  final InstrumentRepository _repository;
  const DisconnectInstrument(this._repository);

  Future<void> call() async => await _repository.disconnect();
}
