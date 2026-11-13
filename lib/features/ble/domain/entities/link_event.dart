import 'package:powerstream_flutter/core/protocol/instrument_status.dart';

sealed class LinkEvent {
  const LinkEvent();
}

final class LinkLost extends LinkEvent {
  const LinkLost();
}

final class StatusChanged extends LinkEvent {
  final InstrumentStatus status;
  const StatusChanged(this.status);
}
