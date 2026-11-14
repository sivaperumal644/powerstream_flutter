part of 'instrument_connection_bloc.dart';

sealed class InstrumentConnectionEvent {
  const InstrumentConnectionEvent();
}

final class ConnectRequestedEvent extends InstrumentConnectionEvent {
  const ConnectRequestedEvent();
}

final class StartRequestedEvent extends InstrumentConnectionEvent {
  final SampleRate rate;
  const StartRequestedEvent(this.rate);
}

final class StopRequestedEvent extends InstrumentConnectionEvent {
  const StopRequestedEvent();
}

final class DisconnectRequestedEvent extends InstrumentConnectionEvent {
  const DisconnectRequestedEvent();
}

final class _LinkLostEvent extends InstrumentConnectionEvent {
  const _LinkLostEvent();
}

final class _StatusChangedEvent extends InstrumentConnectionEvent {
  final InstrumentStatus status;
  const _StatusChangedEvent(this.status);
}

final class _ReconnectAttemptDueEvent extends InstrumentConnectionEvent {
  const _ReconnectAttemptDueEvent();
}
