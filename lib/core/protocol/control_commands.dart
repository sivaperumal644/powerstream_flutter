import 'dart:typed_data';

import 'package:collection/collection.dart';

enum SampleRate {
  hz100(100),
  hz500(500),
  hz2000(2000);

  final int hz;
  const SampleRate(this.hz);

  static SampleRate? fromHz(int hz) =>
      values.firstWhereOrNull((v) => v.hz == hz);
}

abstract final class ControlCommands {
  static Uint8List start() => Uint8List.fromList([ControlOpcodes.start]);

  static Uint8List stop() => Uint8List.fromList([ControlOpcodes.stop]);

  static Uint8List setRate(SampleRate rate) {
    final data = ByteData(3);
    data.setUint8(0, ControlOpcodes.setRate);
    data.setUint16(1, rate.hz, Endian.little);
    return data.buffer.asUint8List();
  }
}

abstract final class ControlOpcodes {
  static const start = 0x01;
  static const stop = 0x02;
  static const setRate = 0x03;
}

/// ATT error codes the Control characteristic can return (section 3).
abstract final class ControlAttErrors {
  static const requestNotSupported =
      0x06; // empty write / unknown opcode / long write
  static const invalidOffset = 0x07; // write with a non-zero offset
  static const invalidAttributeLength = 0x0D; // wrong length for the opcode
  static const invalidRate = 0x80; // SET_RATE value not 100/500/2000
  static const notIdle = 0x81; // SET_RATE while streaming or in error
}
