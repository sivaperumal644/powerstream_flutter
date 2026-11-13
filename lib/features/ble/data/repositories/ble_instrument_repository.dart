import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:powerstream_flutter/core/protocol/control_commands.dart';
import 'package:powerstream_flutter/core/protocol/instrument_info.dart';
import 'package:powerstream_flutter/core/protocol/instrument_status.dart';
import 'package:powerstream_flutter/core/protocol/protocol_constants.dart';
import 'package:powerstream_flutter/features/ble/data/datasources/ble_data_source.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/connected_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/discovered_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/link_event.dart';
import 'package:powerstream_flutter/features/ble/domain/failures/instrument_failure.dart';
import 'package:powerstream_flutter/features/ble/domain/repositories/instrument_repository.dart';

class BleInstrumentRepository implements InstrumentRepository {
  final BleDataSource _bleDS;
  BleInstrumentRepository(this._bleDS) {
    _bleSubs.add(_bleDS.notification.listen(_onNotification));
    _bleSubs.add(_bleDS.connectionChanges.listen(_onConnectionChanged));
  }

  bool _connected = false;
  InstrumentStatus? _latestStatus;
  int? _mtu;

  final _linkEvents = StreamController<LinkEvent>.broadcast();
  final _rawPackets = StreamController<Uint8List>.broadcast();

  final _statuses = StreamController<InstrumentStatus>.broadcast();

  final _bleSubs = <StreamSubscription<Object?>>[];

  final _connectTimeout = const Duration(seconds: 10);
  final _confirmTimeout = const Duration(seconds: 3);

  void _onNotification(BleNotification n) {
    if (n.characteristicUuid == PowerSimUuids.data) {
      _rawPackets.add(n.value);
    } else if (n.characteristicUuid == PowerSimUuids.status) {
      final status = InstrumentStatus.tryDecode(n.value);
      if (status == null) {
        developer.log("Malformed Status Notification: ${n.value}", name: 'ble');
        return;
      }
      _statuses.add(status);
      _latestStatus = status;
      _linkEvents.add(StatusChanged(status));
    }
  }

  void _onConnectionChanged(bool isConnected) {
    if (!isConnected && _connected) {
      _connected = false;
      _latestStatus = null;
      _mtu = null;
      _linkEvents.add(LinkLost());
    }
  }

  Future<void> _writeRate(SampleRate rate) async {
    final bytes = ControlCommands.setRate(rate);
    await _bleDS.write(PowerSimUuids.service, PowerSimUuids.control, bytes);
  }

  InstrumentInfo _parseInfo(Uint8List bytes) {
    final InstrumentInfo info;
    try {
      info = InstrumentInfo.fromJsonBytes(bytes);
    } on FormatException catch (e) {
      throw MalformedInfo(e.message);
    }

    if (!info.isSupportedProtocol) {
      throw UnsupportedProtocolVersion(info.protocolVersion);
    }
    if (!info.hasExpectedChannelOrder) {
      throw UnexpectedChannelOrder(info.channels);
    }
    return info;
  }

  @override
  Future<DiscoveredInstrument> findInstrument({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await _bleDS.ensureAdapterReady();
    return await _bleDS.scanForServices(
      PowerSimUuids.service,
      timeout: timeout,
    );
  }

  @override
  Future<ConnectedInstrument> connect(DiscoveredInstrument instrument) async {
    await _bleDS.connect(instrument.id, timeout: _connectTimeout);
    try {
      final services = await _bleDS.discoverServices();
      if (!services.contains(PowerSimUuids.service)) {
        throw NotAPowerStreamInstrument();
      }

      final mtu = await _bleDS.requestMtu(MtuRules.requested);
      final maxN = MtuRules.maxSamplesFor(mtu);
      if (maxN < 1) throw MtuTooSmall(mtu);

      final info = _parseInfo(
        await _bleDS.read(PowerSimUuids.service, PowerSimUuids.info),
      );
      await _bleDS.subscribe(PowerSimUuids.service, PowerSimUuids.status);
      await _bleDS.subscribe(PowerSimUuids.service, PowerSimUuids.data);

      final status = InstrumentStatus.tryDecode(
        await _bleDS.read(PowerSimUuids.service, PowerSimUuids.status),
      );
      if (status == null) {
        throw MalformedStatus();
      }

      _mtu = mtu;
      _latestStatus = status;
      _connected = true;
      return ConnectedInstrument(
        info: info,
        status: status,
        mtu: mtu,
        maxSamplesPerPacket: maxN,
      );
    } catch (_) {
      await _bleDS.disconnect();
      rethrow;
    }
  }

  @override
  Stream<LinkEvent> get linkEvents => _linkEvents.stream;

  @override
  Stream<Uint8List> get rawPackets => _rawPackets.stream;

  @override
  Future<void> setRate(SampleRate rate) async {
    try {
      await _writeRate(rate);
    } on TimeoutException {
      try {
        await _writeRate(rate);
      } on TimeoutException {
        throw const UnexpectedBleError('Set rate was not acknowledged.');
      }
    }
  }

  @override
  Future<void> start() async {
    if (_latestStatus?.runState == InstrumentRunState.streaming) return;
    final outcome = _statuses.stream
        .firstWhere(
          (s) =>
              s.runState == InstrumentRunState.streaming ||
              s.runState == InstrumentRunState.error,
        )
        .timeout(_confirmTimeout);
    try {
      await _bleDS.write(
        PowerSimUuids.service,
        PowerSimUuids.control,
        ControlCommands.start(),
      );
    } on InstrumentFailure {
      outcome.ignore();
      rethrow;
    }
    final InstrumentStatus status;
    try {
      status = await outcome;
    } on TimeoutException {
      throw StartNotConfirmed();
    }
    if (status.runState == InstrumentRunState.error) {
      throw status.errorCode == InstrumentErrorCode.mtuTooSmall
          ? MtuTooSmall(_mtu ?? 0)
          : UnexpectedBleError(
              "Instrument Error ${status.errorCode.name} after START",
            );
    }
  }

  @override
  Future<void> stop() async {
    if (_latestStatus?.runState == InstrumentRunState.idle) return;

    for (var attempt = 1; attempt <= 2; attempt++) {
      final idle = _statuses.stream
          .firstWhere((s) => s.runState == InstrumentRunState.idle)
          .timeout(_confirmTimeout);
      try {
        _bleDS.write(
          PowerSimUuids.service,
          PowerSimUuids.control,
          ControlCommands.stop(),
        );
      } on InstrumentFailure {
        idle.ignore();
        rethrow;
      }

      try {
        await idle;
        return;
      } catch (_) {}
    }
    throw StopNotConfirmed();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _latestStatus = null;
    _mtu = null;
    await _bleDS.disconnect();
  }

  @override
  Future<void> dispose() async {
    for (final s in _bleSubs) {
      await s.cancel();
    }
    _bleSubs.clear();
    await _statuses.close();
    await _linkEvents.close();
    await _rawPackets.close();
  }
}
