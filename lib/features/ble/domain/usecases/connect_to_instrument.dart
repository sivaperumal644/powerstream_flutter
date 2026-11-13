import 'package:powerstream_flutter/features/ble/domain/entities/connected_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/discovered_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/repositories/instrument_repository.dart';

class ConnectToInstrument {
  final InstrumentRepository _repository;
  const ConnectToInstrument(this._repository);

  Future<ConnectedInstrument> call(DiscoveredInstrument instrument) async =>
      await _repository.connect(instrument);
}
