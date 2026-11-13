import 'package:powerstream_flutter/core/error/failure.dart';

sealed class InstrumentFailure extends Failure {
  const InstrumentFailure(super.message);
}

// Platform/Permission failures

final class BluetoothOff extends InstrumentFailure {
  const BluetoothOff() : super("Bluetooth is turned off");
}

final class BluetoothUnsupported extends InstrumentFailure {
  const BluetoothUnsupported()
    : super("No usable Bluetooth LE Adapter found in this device.");
}

final class BluetoothPermissionDenied extends InstrumentFailure {
  const BluetoothPermissionDenied() : super("Bluetooth Permission was denied");
}

// Instrument connection failures

final class InstrumentNotFound extends InstrumentFailure {
  const InstrumentNotFound()
    : super("No Powerstream Instrument was found nearby.");
}

final class ConnectionTimeout extends InstrumentFailure {
  const ConnectionTimeout() : super("The instrument did not respond in time.");
}

final class DeviceLost extends InstrumentFailure {
  const DeviceLost() : super("The connection to the instrument was lost.");
}

// Protocol checks during setup failures

final class MtuTooSmall extends InstrumentFailure {
  final int mtu;
  const MtuTooSmall(this.mtu)
    : super("MTU - $mtu was too small to carry one sample");
}

final class MalformedInfo extends InstrumentFailure {
  const MalformedInfo(String detail)
    : super("Invalid instrument detail: $detail");
}

final class MalformedStatus extends InstrumentFailure {
  const MalformedStatus() : super("Invalid Instrument Status");
}

final class UnsupportedProtocolVersion extends InstrumentFailure {
  final int version;
  const UnsupportedProtocolVersion(this.version)
    : super("Unsupported Protocol Version: $version");
}

final class UnexpectedChannelOrder extends InstrumentFailure {
  final List<String> channels;
  UnexpectedChannelOrder(this.channels)
    : super("Unexpected channel order: ${channels.join(', ')}");
}

// Commands failure

final class CommandRejected extends InstrumentFailure {
  final int? attErrorCode;
  const CommandRejected(this.attErrorCode)
    : super("The command was rejected because of the ATT Error: $attErrorCode");
}

final class StartNotConfirmed extends InstrumentFailure {
  const StartNotConfirmed()
    : super("The start was not confirmed by the device");
}

final class StopNotConfirmed extends InstrumentFailure {
  const StopNotConfirmed() : super("The stop was not confirmed by the device");
}

// Unknown failures

final class UnexpectedBleError extends InstrumentFailure {
  const UnexpectedBleError(String details)
    : super("Unexpected Ble error: $details");
}

final class RateNotSupported extends InstrumentFailure {
  final int hz;
  const RateNotSupported(this.hz)
    : super("The instument do not support $hz rate");
}

final class NotAPowerStreamInstrument extends InstrumentFailure {
  const NotAPowerStreamInstrument()
    : super("The connected device does not offer powerstream service");
}
