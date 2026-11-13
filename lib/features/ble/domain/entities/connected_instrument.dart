import 'package:equatable/equatable.dart';
import 'package:powerstream_flutter/core/protocol/instrument_info.dart';
import 'package:powerstream_flutter/core/protocol/instrument_status.dart';

class ConnectedInstrument extends Equatable {
  final InstrumentInfo info;
  final InstrumentStatus status;
  final int mtu;
  final int maxSamplesPerPacket;

  const ConnectedInstrument({
    required this.info,
    required this.status,
    required this.mtu,
    required this.maxSamplesPerPacket,
  });

  @override
  List<Object?> get props => [info, status, mtu, maxSamplesPerPacket];
}
