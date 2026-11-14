import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum InstrumentRunState { idle, streaming, error, unknown }

enum InstrumentErrorCode {
  none,
  badCommand,
  mtuTooSmall,
  queueOverflow,
  unknown,
}

class InstrumentStatus extends Equatable {
  final InstrumentRunState runState;
  final InstrumentErrorCode errorCode;
  final int batteryPercent;

  const InstrumentStatus({
    required this.runState,
    required this.errorCode,
    required this.batteryPercent,
  });

  bool get isStreaming => runState == InstrumentRunState.streaming;

  static InstrumentStatus? tryDecode(Uint8List bytes) {
    if (bytes.length < 4) return null;
    return InstrumentStatus(
      runState: switch (bytes[0]) {
        0 => InstrumentRunState.idle,
        1 => InstrumentRunState.streaming,
        2 => InstrumentRunState.error,
        _ => InstrumentRunState.unknown,
      },
      batteryPercent: bytes[1],
      errorCode: switch (bytes[2]) {
        0 => InstrumentErrorCode.none,
        1 => InstrumentErrorCode.badCommand,
        2 => InstrumentErrorCode.mtuTooSmall,
        3 => InstrumentErrorCode.queueOverflow,
        _ => InstrumentErrorCode.unknown,
      },
    );
  }

  @override
  List<Object?> get props => [runState, batteryPercent, errorCode];
}

extension BatterStatus on InstrumentStatus {
  static const lowThresholdPercent = 20;
  bool get isBatteryLow => batteryPercent < lowThresholdPercent;
}
