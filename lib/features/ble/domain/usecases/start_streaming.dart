import 'package:powerstream_flutter/core/protocol/control_commands.dart';
import 'package:powerstream_flutter/core/protocol/instrument_info.dart';
import 'package:powerstream_flutter/features/ble/domain/failures/instrument_failure.dart';
import 'package:powerstream_flutter/features/ble/domain/repositories/instrument_repository.dart';

class StartStreaming {
  final InstrumentRepository _repository;
  const StartStreaming(this._repository);

  Future<void> call(InstrumentInfo info, SampleRate rate) async {
    if (!info.supportsRate(rate)) {
      throw RateNotSupported(rate.hz);
    }
    await _repository.setRate(rate);
    await _repository.start();
  }
}
