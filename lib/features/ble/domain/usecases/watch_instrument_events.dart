import 'package:powerstream_flutter/features/ble/domain/entities/link_event.dart';
import 'package:powerstream_flutter/features/ble/domain/repositories/instrument_repository.dart';

class WatchInstrumentEvents {
  final InstrumentRepository _repository;
  const WatchInstrumentEvents(this._repository);

  Stream<LinkEvent> call() => _repository.linkEvents;
}
