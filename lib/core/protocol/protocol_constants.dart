abstract final class PowerSimUuids {
  static const String _suffix = "-8c3b-4d2e-9a51-3e7b2c4d5f60";
  static const String service = "6f1a0000$_suffix";
  static const String data = "6f1a0001$_suffix"; // Notify
  static const String control = "6f1a0002$_suffix"; // Write with response
  static const String status = "6f1a0003$_suffix"; // Read and notify
  static const String info = "6f1a0004$_suffix"; // Read (Long read)
}

abstract final class PacketLayout {
  static const int version = 1;
  static const int headerSize = 18; // Bytes before the sample
  static const int crcSize = 2; // CRC at the end
  static const int minLength = headerSize + crcSize; // A packet with 0 samples
  static const int sampleSize = 16; // 4 x float32
  static const int valuesPerSample = 4; // volatage, current, frequency, power
  static const int maxSamples = 30;

  static const List<String> channels = [
    "voltage",
    "current",
    "frequency",
    "power",
  ];
}

abstract final class MtuRules {
  static const int requested = 517;
  static const int notifyOverhead = 3; // opcode(1) + handle(2)

  static int maxSamplesFor(int mtu) {
    final n =
        (mtu - notifyOverhead - PacketLayout.minLength) ~/
        PacketLayout.sampleSize;
    if (n < 0) return 0;
    return n > PacketLayout.maxSamples ? PacketLayout.maxSamples : n;
  }
}
