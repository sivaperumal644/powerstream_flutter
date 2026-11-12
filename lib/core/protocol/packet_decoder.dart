import 'dart:typed_data';

import 'package:powerstream_flutter/core/protocol/crc16.dart';
import 'package:powerstream_flutter/core/protocol/protocol_constants.dart';

enum DecodeErrorKind { tooShort, lengthMismatch, badCrc, badVersion }

sealed class DecodedResult {
  DecodedResult();
}

final class DecodedError extends DecodedResult {
  final DecodeErrorKind errorKind;
  final int bytesLength;

  DecodedError({required this.errorKind, required this.bytesLength});
}

final class DecodedPacket extends DecodedResult {
  final int flags;
  final int packetSeq;
  final int firstSampleTimeStampUs;
  final int sampleRateHz;
  final int sampleCount;
  final Float32List samples;

  DecodedPacket({
    required this.flags,
    required this.packetSeq,
    required this.firstSampleTimeStampUs,
    required this.sampleRateHz,
    required this.sampleCount,
    required this.samples,
  });

  bool get isFirstAfterStart => (flags & 0x01) != 0;

  int get samplePeriodUs => 100000 ~/ sampleRateHz;

  int get windowUs => sampleCount * samplePeriodUs;

  int get expectedNextTimeStampUs => firstSampleTimeStampUs + windowUs;

  int timeStampOfSampleUs(int i) => firstSampleTimeStampUs + i * samplePeriodUs;
}

abstract final class PacketDecoder {
  DecodedResult decodePacket(Uint8List bytes) {
    final length = bytes.length;

    if (length < PacketLayout.minLength) {
      return DecodedError(
        errorKind: DecodeErrorKind.tooShort,
        bytesLength: length,
      );
    }

    final view = ByteData.sublistView(bytes);

    final n = view.getUint16(16, Endian.little);
    if (length != PacketLayout.minLength + PacketLayout.sampleSize * n) {
      return DecodedError(
        errorKind: DecodeErrorKind.lengthMismatch,
        bytesLength: length,
      );
    }

    final crcOffset = length - PacketLayout.crcSize;
    final storedCrc = view.getUint16(crcOffset, Endian.little);

    if (Crc16.crc16CcittFalse(bytes, end: crcOffset) != storedCrc) {
      return DecodedError(
        errorKind: DecodeErrorKind.badCrc,
        bytesLength: length,
      );
    }

    if (bytes[0] != PacketLayout.version) {
      return DecodedError(
        errorKind: DecodeErrorKind.badVersion,
        bytesLength: length,
      );
    }

    final values = Float32List(n * PacketLayout.valuesPerSample);
    for (var i = 0; i < values.length; i++) {
      values[i] = view.getFloat32(
        PacketLayout.headerSize + i * 4,
        Endian.little,
      );
    }

    return DecodedPacket(
      flags: bytes[0],
      packetSeq: view.getUint32(2, Endian.little),
      firstSampleTimeStampUs: view.getUint64(6, Endian.little),
      sampleRateHz: view.getUint16(14, Endian.little),
      sampleCount: n,
      samples: values,
    );
  }
}
