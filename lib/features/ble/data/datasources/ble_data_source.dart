import 'dart:typed_data';

import 'package:powerstream_flutter/features/ble/domain/entities/discovered_instrument.dart';

typedef BleNotification = ({String characteristicUuid, Uint8List value});

abstract interface class BleDataSource {
  Stream<BleNotification> get notification;

  Stream<bool> get connectionChanges;

  Future<void> ensureAdapterReady();
  Future<DiscoveredInstrument> scanForServices(
    String serviceUuid, {
    required Duration timeout,
  });
  Future<void> connect(String deviceId, {required Duration timeout});
  Future<List<String>> discoverServices();
  Future<int> requestMtu(int mtu);
  Future<Uint8List> read(String serviceUuid, String characteristicsUuid);
  Future<void> write(
    String serviceUuid,
    String characteristicsUuid,
    Uint8List value,
  );
  Future<void> subscribe(String serviceUuid, String characteristicsUuid);

  Future<void> disconnect();

  Future<void> dispose();
}
