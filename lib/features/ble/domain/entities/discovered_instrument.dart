import 'package:equatable/equatable.dart';

class DiscoveredInstrument extends Equatable {
  final String id;
  final String? name;
  final int? rssi;

  const DiscoveredInstrument({
    required this.id,
    required this.name,
    required this.rssi,
  }); //signal strength in dBm (Closer to 0 is stronger).

  @override
  List<Object?> get props => [id, name, rssi];
}
