import 'dart:typed_data';

import 'package:powerstream_flutter/core/protocol/control_commands.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/connected_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/discovered_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/link_event.dart';

abstract interface class InstrumentRepository {
  Future<DiscoveredInstrument> findInstrument({
    Duration timeout = const Duration(seconds: 15),
  });

  Future<ConnectedInstrument> connect(DiscoveredInstrument instrument);

  Stream<LinkEvent> get linkEvents;

  Stream<Uint8List> get rawPackets;

  Future<void> start();

  Future<void> stop();

  Future<void> setRate(SampleRate rate);

  Future<void> disconnect();

  Future<void> dispose();
}
