part of 'instrument_connection_bloc.dart';

sealed class InstrumentConnectionState extends Equatable {
  const InstrumentConnectionState();

  @override
  List<Object?> get props => [];
}

final class IdleState extends InstrumentConnectionState {
  const IdleState();
}

final class ScanningState extends InstrumentConnectionState {
  const ScanningState();
}

final class ConnectingState extends InstrumentConnectionState {
  final DiscoveredInstrument found;
  const ConnectingState(this.found);

  @override
  List<Object?> get props => [found];
}

final class ConnectedState extends InstrumentConnectionState {
  final ConnectedInstrument instrument;
  final InstrumentStatus status;
  final bool busy;
  final InstrumentFailure? failure;

  const ConnectedState({
    required this.instrument,
    required this.status,
    this.busy = false,
    this.failure,
  });

  @override
  List<Object?> get props => [instrument, status, busy];
}

final class StreamingState extends InstrumentConnectionState {
  final ConnectedInstrument instrument;
  final InstrumentStatus status;
  final SampleRate rate;
  final bool busy;
  final InstrumentFailure? failure;

  const StreamingState({
    required this.instrument,
    required this.status,
    required this.rate,
    this.busy = false,
    this.failure,
  });

  @override
  List<Object?> get props => [instrument, status, rate, busy];
}

final class ReconnectingState extends InstrumentConnectionState {
  final int attempt;
  final Duration nextTryIn;
  final SampleRate? resumeRate;

  const ReconnectingState({
    required this.attempt,
    required this.nextTryIn,
    this.resumeRate,
  });

  @override
  List<Object?> get props => [attempt, nextTryIn, resumeRate];
}

final class FailedState extends InstrumentConnectionState {
  final InstrumentFailure failure;
  const FailedState(this.failure);
}
