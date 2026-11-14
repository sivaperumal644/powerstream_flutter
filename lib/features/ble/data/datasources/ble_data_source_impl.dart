import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:powerstream_flutter/features/ble/data/datasources/ble_data_source.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/discovered_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/failures/instrument_failure.dart';
import 'package:universal_ble/universal_ble.dart';

class BleDataSourceImpl implements BleDataSource {
  final _foundDevices = <String, BleDevice>{};
  BleDevice? _connectedDevice;
  final _characteristics = <String, BleCharacteristic>{};
  final _notificationSubs = <StreamSubscription<Uint8List>>[];
  StreamSubscription<bool>? _connectionSub;

  final _notifications = StreamController<BleNotification>.broadcast();
  final _connections = StreamController<bool>.broadcast();

  @override
  Stream<bool> get connectionChanges => _connections.stream;

  @override
  Stream<BleNotification> get notification => _notifications.stream;

  @override
  Future<void> ensureAdapterReady() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    switch (state) {
      case AvailabilityState.poweredOn:
        return;
      case AvailabilityState.poweredOff:
        throw const BluetoothOff();
      case AvailabilityState.unsupported:
        throw const BluetoothUnsupported();
      case AvailabilityState.unauthorized:
        throw const BluetoothPermissionDenied();
      default:
        throw UnexpectedBleError('Bluetooth State: $state');
    }
  }

  @override
  Future<DiscoveredInstrument> scanForServices(
    String serviceUuid, {
    required Duration timeout,
  }) async {
    _foundDevices.clear();
    final firstResult = UniversalBle.scanStream.first.timeout(timeout);
    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [serviceUuid]),
      );
    } catch (e) {
      firstResult.ignore();
      throw UnexpectedBleError('$e');
    }

    try {
      final device = await firstResult;
      _foundDevices[device.deviceId] = device;
      return DiscoveredInstrument(
        id: device.deviceId,
        name: device.name,
        rssi: device.rssi,
      );
    } on TimeoutException {
      throw const InstrumentNotFound();
    } finally {
      await UniversalBle.stopScan();
    }
  }

  @override
  Future<void> connect(String deviceId, {required Duration timeout}) async {
    final device = _foundDevices[deviceId];
    if (device == null) {
      throw const UnexpectedBleError(
        "Unknown Ble Error, Scan Before Connecting",
      );
    }

    try {
      await device.connect().timeout(timeout);
    } on TimeoutException {
      throw const ConnectionTimeout();
    } catch (e) {
      throw UnexpectedBleError('$e');
    }

    _connectedDevice = device;
    _connectionSub = _connectedDevice?.connectionStream.listen((connected) {
      developer.log('connectionStream: $connected', name: 'ble');
      if (!connected) _releaseConnection();
      _connections.add(connected);
    });
  }

  @override
  Future<List<String>> discoverServices() async {
    final services = await _guard(() => _requireDevice().discoverServices());
    return services.map((s) => s.uuid).toList();
  }

  @override
  Future<int> requestMtu(int mtu) async =>
      await _guard(() => _requireDevice().requestMtu(mtu));

  Future<BleCharacteristic> _characteristic(String service, String uuid) async {
    final cached = _characteristics[uuid];
    if (cached != null) return cached;
    final found = await _guard(
      () => _requireDevice().getCharacteristic(uuid, service: service),
    );
    _characteristics[uuid] = found;
    return found;
  }

  @override
  Future<Uint8List> read(String serviceUuid, String characteristicsUuid) async {
    final c = await _characteristic(serviceUuid, characteristicsUuid);
    return _guard(() => c.read());
  }

  @override
  Future<void> write(
    String serviceUuid,
    String characteristicsUuid,
    Uint8List value,
  ) async {
    final c = await _characteristic(serviceUuid, characteristicsUuid);
    try {
      await _guard(() => c.write(value, withResponse: true));
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw CommandRejected(null);
    }
  }

  @override
  Future<void> subscribe(String serviceUuid, String characteristicsUuid) async {
    final c = await _characteristic(serviceUuid, characteristicsUuid);
    _notificationSubs.add(
      c.onValueReceived.listen(
        (value) => _notifications.add((
          characteristicUuid: characteristicsUuid,
          value: value,
        )),
      ),
    );
    await _guard(() => c.notifications.subscribe());
  }

  @override
  Future<void> disconnect() async {
    final device = _connectedDevice;
    await _releaseConnection();
    try {
      await device?.disconnect();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _releaseConnection();
    await _notifications.close();
    await _connections.close();
  }

  Future<void> _releaseConnection() async {
    final subs = [..._notificationSubs];
    _notificationSubs.clear();
    for (final s in subs) {
      await s.cancel();
    }
    final connectionSub = _connectionSub;
    _connectionSub = null;
    await connectionSub?.cancel();
    _characteristics.clear();
    _connectedDevice = null;
  }

  BleDevice _requireDevice() => _connectedDevice ?? (throw const DeviceLost());

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on InstrumentFailure {
      rethrow;
    } catch (e) {
      throw UnexpectedBleError('$e');
    }
  }
}
