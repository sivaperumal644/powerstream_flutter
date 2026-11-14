import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powerstream_flutter/core/protocol/control_commands.dart';
import 'package:powerstream_flutter/core/protocol/instrument_status.dart';
import 'package:powerstream_flutter/features/ble/domain/entities/connected_instrument.dart';
import 'package:powerstream_flutter/features/ble/domain/failures/instrument_failure.dart';
import 'package:powerstream_flutter/features/ble/presentation/bloc/instrument_connection_bloc.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<InstrumentConnectionBloc, InstrumentConnectionState>(
          builder: (context, state) => switch (state) {
            IdleState() => const _IdleView(),
            ScanningState() => const _ProgressView(
              'Scanning for the instrument',
            ),
            ConnectingState(:final found) => _ProgressView(
              'Connecting to ${found.name ?? found.id}...',
            ),
            ConnectedState s => _ConnectedView(state: s),
            StreamingState s => _StreamingView(state: s),
            ReconnectingState s => _ReconnectingView(state: s),
            FailedState(:final failure) => _FailedView(failure: failure),
          },
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Not connected'),
        const SizedBox(height: 15),
        FilledButton(
          onPressed: () => context.read<InstrumentConnectionBloc>().add(
            const ConnectRequestedEvent(),
          ),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}

class _ProgressView extends StatelessWidget {
  final String message;
  const _ProgressView(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text('message'),
      ],
    );
  }
}

class _InstrumentCard extends StatelessWidget {
  final ConnectedInstrument instrument;
  final InstrumentStatus status;
  const _InstrumentCard({required this.instrument, required this.status});

  @override
  Widget build(BuildContext context) {
    final info = instrument.info;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.device, style: Theme.of(context).textTheme.titleMedium),
            Text('Turbine ${info.turbineId} - firmware ${info.firmware}'),
            Text(
              'MTU ${instrument.mtu} - up to ${instrument.maxSamplesPerPacket} samples/packet',
            ),
            Text('Battery ${status.batteryPercent}%'),
            if (status.errorCode == InstrumentErrorCode.queueOverflow)
              const Text(
                '⚠ Instrument queue overflow: packets are being dropped',
              ),
            if (status.errorCode != InstrumentErrorCode.none &&
                status.errorCode != InstrumentErrorCode.queueOverflow)
              Text('Instrument error: ${status.errorCode.name}'),
          ],
        ),
      ),
    );
  }
}

class _ConnectedView extends StatefulWidget {
  final ConnectedState state;
  const _ConnectedView({required this.state});

  @override
  State<_ConnectedView> createState() => _ConnectedViewState();
}

class _ConnectedViewState extends State<_ConnectedView> {
  SampleRate _rate = SampleRate.hz2000;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bloc = context.read<InstrumentConnectionBloc>();
    final supported = SampleRate.values.where(
      state.instrument.info.supportsRate,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InstrumentCard(instrument: state.instrument, status: state.status),
        const SizedBox(height: 16),
        SegmentedButton<SampleRate>(
          segments: supported
              .map((r) => ButtonSegment(value: r, label: Text('${r.hz} Hz')))
              .toList(),
          selected: {_rate},
          onSelectionChanged: state.busy
              ? null
              : (s) => setState(() => _rate = s.first),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(
              onPressed: state.busy
                  ? null
                  : () => bloc.add(StartRequestedEvent(_rate)),
              child: state.busy ? const Text('Starting...') : Text('Start'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () => bloc.add(DisconnectRequestedEvent()),
              child: const Text('Disconnect'),
            ),
          ],
        ),
        if (state.failure != null) ...[
          const SizedBox(height: 12),
          Text(
            state.failure!.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _StreamingView extends StatelessWidget {
  final StreamingState state;
  const _StreamingView({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<InstrumentConnectionBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InstrumentCard(instrument: state.instrument, status: state.status),
        const SizedBox(height: 16),
        Text('Recording at ${state.rate.hz} Hz'),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(
              onPressed: state.busy
                  ? null
                  : () => bloc.add(StopRequestedEvent()),
              child: state.busy ? const Text('Stopping...') : Text('Stop'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () => bloc.add(DisconnectRequestedEvent()),
              child: const Text('Disconnect'),
            ),
          ],
        ),
        if (state.failure != null) ...[
          const SizedBox(height: 12),
          Text(
            state.failure!.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _ReconnectingView extends StatelessWidget {
  final ReconnectingState state;
  const _ReconnectingView({required this.state});

  @override
  Widget build(BuildContext context) {
    final seconds = (state.nextTryIn.inMilliseconds / 1000).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressView(
          'Connection Lost. Reconnecting, attempt ${state.attempt}, next try in $seconds s',
        ),
        if (state.resumeRate != null)
          Text('Recording will resume at ${state.resumeRate!.hz} Hz.'),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.read<InstrumentConnectionBloc>().add(
            const DisconnectRequestedEvent(),
          ),
          child: const Text('Stop Trying'),
        ),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  final InstrumentFailure failure;
  const _FailedView({required this.failure});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          failure.message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        Text(_hintFor()),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.read<InstrumentConnectionBloc>().add(
            const ConnectRequestedEvent(),
          ),
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  String _hintFor() => switch (failure) {
    BluetoothOff() => 'Turn on Bluetooth, then try again.',
    BluetoothPermissionDenied() =>
      'Allow the Bluetooth permission in system settings.',
    BluetoothUnsupported() => 'This computer has no Bluetooth LE adapter.',
    InstrumentNotFound() => 'Is the instrument on, advertising and close by?',
    MtuTooSmall() => 'This Bluetooth adapter cannot carry full packets.',
    NotAPowerStreamInstrument() ||
    UnsupportedProtocolVersion() ||
    UnexpectedChannelOrder() ||
    MalformedInfo() =>
      'This instrument is not compatible with this app version.',
    _ => 'Try again. If it keeps failing, restart the instrument.',
  };
}
