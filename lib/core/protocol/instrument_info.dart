import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:powerstream_flutter/core/protocol/control_commands.dart';
import 'package:powerstream_flutter/core/protocol/protocol_constants.dart';

class InstrumentInfo extends Equatable {
  final String device;
  final String turbineId;
  final String firmware;
  final int protocolVersion;
  final List<int> sampleRates;
  final List<String> channels;

  const InstrumentInfo({
    required this.device,
    required this.turbineId,
    required this.firmware,
    required this.protocolVersion,
    required this.sampleRates,
    required this.channels,
  });

  bool get isSupportedProtocol => protocolVersion == PacketLayout.version;

  bool get hasExpectedChannelOrder =>
      listEquals(channels, PacketLayout.channels);

  bool supportsRate(SampleRate rate) => sampleRates.contains(rate.hz);

  factory InstrumentInfo.fromJsonBytes(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(bytes));

    if (json case {
      'device': String device,
      'turbineId': String turbineId,
      'firmware': String firmware,
      'protocolVersion': int protocolVersion,
      'sampleRates': List<Object?> sampleRates,
      'channels': List<Object?> channels,
    }) {
      if (sampleRates.any((r) => r is! int) ||
          channels.any((c) => c is! String)) {
        throw const FormatException(
          "Info: sampleRates must be numbers, channels must be text",
        );
      }
      return InstrumentInfo(
        device: device,
        turbineId: turbineId,
        firmware: firmware,
        protocolVersion: protocolVersion,
        sampleRates: List.unmodifiable(sampleRates.cast<int>()),
        channels: List.unmodifiable(channels.cast<String>()),
      );
    }
    throw const FormatException(
      "Info Json is missing fields or has a wrong data types",
    );
  }

  @override
  List<Object?> get props => [
    device,
    turbineId,
    firmware,
    protocolVersion,
    sampleRates,
    channels,
  ];
}
