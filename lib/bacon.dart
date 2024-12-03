// beacon.dart
class Beacon {
  final String mac;
  final int rssi;
  final String name;
  final String uuid;
  final int? major;
  final int? minor;

  Beacon({
    required this.mac,
    required this.rssi,
    required this.name,
    required this.uuid,
    this.major,
    this.minor,
  });

  factory Beacon.fromMap(Map<String, dynamic> map) {
    return Beacon(
      mac: map['mac'] ?? 'unknown',
      rssi: map['rssi'] ?? 0,
      name: map['name'] ?? 'Unknown',
      uuid: map['uuid'] ?? 'unknown',
      major: map['major'],
      minor: map['minor'],
    );
  }
}
