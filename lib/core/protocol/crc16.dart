abstract final class Crc16 {
  static int crc16CcittFalse(List<int> bytes, {int start = 0, int? end}) {
    final int stop = end ?? bytes.length;

    int crc = 0xFFFF;

    for (int i = start; i < stop; i++) {
      crc ^= (bytes[i] & 0xFF) << 8;

      for (var step = 0; step < 8; step++) {
        final leftMostOn = (crc & 0x8000) != 0;
        crc = (crc << 1) & 0xFFFF;
        if (leftMostOn) {
          crc ^= 0x1021;
        }
      }
    }
    return crc;
  }
}
