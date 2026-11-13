import 'package:powerstream_flutter/features/ble/domain/entities/discovered_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/repositories/instrument_repository.dart';

class FindInstrument {
  final InstrumentRepository _repository;
  const FindInstrument(this._repository);

  Future<DiscoveredInstrument> call() async =>
      await _repository.findInstrument();
}
