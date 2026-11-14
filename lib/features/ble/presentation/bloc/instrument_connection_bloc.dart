import 'dart:async';
import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powerstream_flutter/core/protocol/control_commands.dart';
import 'package:powerstream_flutter/core/protocol/instrument_status.dart';
import 'package:powerstream_flutter/core/utils/backoff_policy.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/connected_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/discovered_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/link_event.dart';
import 'package:powerstream_flutter/features/ble/domain/failures/instrument_failure.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/connect_to_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/disconnect_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/find_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/start_streaming.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/stop_streaming.dart';
import 'package:powerstream_flutter/features/ble/domain/usecases/watch_instrument_events.dart';

part 'instrument_connection_event.dart';
part 'instrument_connection_state.dart';

class InstrumentConnectionBloc
    extends Bloc<InstrumentConnectionEvent, InstrumentConnectionState> {
  final FindInstrument _findInstrument;
  final ConnectToInstrument _connectToInstrument;
  final StartStreaming _startStreaming;
  final StopStreaming _stopStreaming;
  final DisconnectInstrument _disconnectInstrument;
  final WatchInstrumentEvents _watchInstrumentEvents;
  final BackoffPolicy _backoff;
  final Random? _random;

  StreamSubscription<LinkEvent>? _linkSub;
  Timer? _reconnectTimer;

  InstrumentConnectionBloc({
    required this._findInstrument,
    required this._connectToInstrument,
    required this._startStreaming,
    required this._stopStreaming,
    required this._disconnectInstrument,
    required this._watchInstrumentEvents,
    this._backoff = const BackoffPolicy(),
    Random? random,
  }) : _random = random ?? Random(),
       super(IdleState()) {
    on<InstrumentConnectionEvent>(_onEvent, transformer: sequential());
    _linkSub = _watchInstrumentEvents().listen(_onInstrumentEventChanges);
  }

  void _onInstrumentEventChanges(LinkEvent linkEvent) {
    switch (linkEvent) {
      case LinkLost():
        add(_LinkLostEvent());
      case StatusChanged():
        add(_StatusChangedEvent(linkEvent.status));
    }
  }

  Future<void> _onEvent(
    InstrumentConnectionEvent event,
    Emitter<InstrumentConnectionState> emit,
  ) async {
    switch (event) {
      case ConnectRequestedEvent():
        await _onConnect(emit);
      case StartRequestedEvent(:final rate):
        await _onStart(emit, rate);
      case StopRequestedEvent():
        await _onStop(emit);
      case DisconnectRequestedEvent():
        await _onDisconnect(emit);
      case _LinkLostEvent():
        _onLinkLost(emit);
      case _StatusChangedEvent(:final status):
        _onStatusChanged(emit, status);
      case _ReconnectAttemptDueEvent():
        await _onReconnectAttempt(emit);
    }
  }

  Future<void> _onConnect(Emitter<InstrumentConnectionState> emit) async {
    if (state is! IdleState && state is! FailedState) return;

    try {
      emit(ScanningState());
      final found = await _findInstrument();
      emit(ConnectingState(found));
      final connected = await _connectToInstrument(found);
      emit(ConnectedState(instrument: connected, status: connected.status));
    } on InstrumentFailure catch (failure) {
      emit(FailedState(failure));
    } catch (e) {
      emit(FailedState(UnexpectedBleError('$e')));
    }
  }

  Future<void> _onStart(
    Emitter<InstrumentConnectionState> emit,
    SampleRate rate,
  ) async {
    final current = state;
    if (current is! ConnectedState || current.busy) return;

    emit(
      ConnectedState(
        instrument: current.instrument,
        status: current.status,
        busy: true,
      ),
    );

    try {
      await _startStreaming(current.instrument.info, rate);
      emit(
        StreamingState(
          instrument: current.instrument,
          status: current.instrument.status,
          rate: rate,
        ),
      );
    } on InstrumentFailure catch (failure) {
      if (failure is StartNotConfirmed || failure is MtuTooSmall) {
        try {
          await _stopStreaming();
        } catch (_) {}
      }
      emit(
        ConnectedState(
          instrument: current.instrument,
          status: current.status,
          failure: failure,
        ),
      );
    }
  }

  Future<void> _onStop(Emitter<InstrumentConnectionState> emit) async {
    final current = state;
    if (current is! StreamingState || current.busy) return;

    emit(
      StreamingState(
        instrument: current.instrument,
        status: current.status,
        rate: current.rate,
        busy: true,
      ),
    );

    try {
      await _stopStreaming();
      emit(
        ConnectedState(instrument: current.instrument, status: current.status),
      );
    } on InstrumentFailure catch (failure) {
      emit(
        StreamingState(
          instrument: current.instrument,
          status: current.status,
          rate: current.rate,
          failure: failure,
        ),
      );
    }
  }

  Future<void> _onDisconnect(Emitter<InstrumentConnectionState> emit) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final current = state;
    if (current is IdleState) return;

    if (current is StreamingState) {
      try {
        await _stopStreaming();
      } catch (_) {}
    }

    try {
      await _disconnectInstrument();
    } catch (_) {}

    emit(const IdleState());
  }

  void _onLinkLost(Emitter<InstrumentConnectionState> emit) {
    switch (state) {
      case StreamingState(:final rate):
        _scheduleReconnect(1, rate, emit);
      case ConnectedState():
        _scheduleReconnect(1, null, emit);
      default:
        return;
    }
  }

  void _onStatusChanged(
    Emitter<InstrumentConnectionState> emit,
    InstrumentStatus status,
  ) {
    switch (state) {
      case ConnectedState(:final instrument, :final busy, :final failure):
        emit(
          ConnectedState(
            instrument: instrument,
            status: status,
            busy: busy,
            failure: failure,
          ),
        );
      case StreamingState(
        :final instrument,
        :final rate,
        :final busy,
        :final failure,
      ):
        emit(
          StreamingState(
            instrument: instrument,
            status: status,
            rate: rate,
            busy: busy,
            failure: failure,
          ),
        );
      default:
    }
  }

  Future<void> _onReconnectAttempt(
    Emitter<InstrumentConnectionState> emit,
  ) async {
    final current = state;
    if (current is! ReconnectingState) return;
    _reconnectTimer = null;

    final ConnectedInstrument connected;
    try {
      final found = await _findInstrument();
      connected = await _connectToInstrument(found);
    } on InstrumentFailure catch (failure) {
      if (_isRetryable(failure) && current.attempt < _backoff.maxAttempts) {
        _scheduleReconnect(current.attempt + 1, current.resumeRate, emit);
      } else {
        emit(FailedState(failure));
      }
      return;
    }

    final resumeRate = current.resumeRate;
    if (resumeRate == null) {
      emit(ConnectedState(instrument: connected, status: connected.status));
      return;
    }

    try {
      await _startStreaming(connected.info, resumeRate);
      emit(
        StreamingState(
          instrument: connected,
          status: connected.status,
          rate: resumeRate,
        ),
      );
    } on InstrumentFailure catch (failure) {
      emit(
        ConnectedState(
          instrument: connected,
          status: connected.status,
          failure: failure,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    await _linkSub?.cancel();
    return super.close();
  }

  void _scheduleReconnect(
    int attempt,
    SampleRate? resumeRate,
    Emitter<InstrumentConnectionState> emit,
  ) {
    final delay = _backoff.delayFor(attempt, _random ?? Random());
    emit(
      ReconnectingState(
        attempt: attempt,
        nextTryIn: delay,
        resumeRate: resumeRate,
      ),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      delay,
      () => add(const _ReconnectAttemptDueEvent()),
    );
  }

  bool _isRetryable(InstrumentFailure failure) => switch (failure) {
    InstrumentNotFound() ||
    ConnectionTimeout() ||
    DeviceLost() ||
    UnexpectedBleError() => true,
    _ => false,
  };
}
