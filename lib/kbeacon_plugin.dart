import 'package:flutter/services.dart';

class KbeaconPlugin {
  static const MethodChannel _channel = MethodChannel('kbeacon_plugin');
  static const EventChannel _eventChannel = EventChannel('kbeacon_plugin_events'); // Updated to match native plugins

  // Stream controllers for different events
  Stream<List<String>>? _scanResultStream;
  Stream<String>? _scanFailedStream;
  Stream<String>? _bleStateChangeStream;

  KbeaconPlugin._privateConstructor();

  static final KbeaconPlugin _instance = KbeaconPlugin._privateConstructor();

  factory KbeaconPlugin() {
    return _instance;
  }

  // Initialize streams
  void initialize() {
    _scanResultStream = _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        if (event.containsKey('onScanResult')) {
          List<String> beacons = List<String>.from(event['onScanResult']);
          return beacons;
        }
      }
      return <String>[];
    });

    _scanFailedStream = _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map && event.containsKey('onScanFailed')) {
        return event['onScanFailed'] as String;
      }
      return '';
    });

    _bleStateChangeStream = _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map && event.containsKey('bluetoothState')) {
        return event['bluetoothState'] as String;
      }
      return '';
    });
  }

  // Start scanning for advertising messages
  Future<void> checkAdvertisingMessages() async {
    try {
      await _channel.invokeMethod('checkAdvertisingMessages');
    } on PlatformException catch (e) {
      throw 'Failed to check advertising messages: ${e.message}';
    }
  }

  // Stream of advertising messages
  Stream<String> listenToAdvertisingMessages() {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
  }

  // ESP BLE Provisioning Methods

  @pragma('vm:entry-point')
  Future<void> scanBleDevices(String prefix) async {
    try {
      await _channel.invokeMethod('scanBleDevices', {'prefix': prefix});
    } on PlatformException catch (e) {
      throw 'Failed to scan BLE devices: ${e.message}';
    }
  }

  Future<void> disconnectDevice() async {
    try {
      await _channel.invokeMethod('disconnectDevice');
    } catch (e) {
      throw Exception('Failed to disconnect device: $e');
    }
  }

  Stream<String> scanBleDevicesAsStream(String prefix) {
    return _eventChannel.receiveBroadcastStream(prefix).map((event) => event.toString());
  }

  // Call the method to ring the device
  static Future<void> ringDevice() async {
    try {
      await _channel.invokeMethod('ringDevice');
    } on PlatformException catch (e) {
      print("Failed to ring device: ${e.message}");
    }
  }

  Future<List<String>> scanWifiNetworks(String deviceName, String proofOfPossession) async {
    try {
      final List<dynamic> networks = await _channel.invokeMethod('scanWifiNetworks', {
        'deviceName': deviceName,
        'proofOfPossession': proofOfPossession,
      });
      return networks.cast<String>();
    } on PlatformException catch (e) {
      throw 'Failed to scan Wi-Fi networks: ${e.message}';
    }
  }

  Future<bool> provisionWifi(
      String deviceName, String proofOfPossession, String ssid, String passphrase) async {
    try {
      final bool result = await _channel.invokeMethod('provisionWifi', {
        'deviceName': deviceName,
        'proofOfPossession': proofOfPossession,
        'ssid': ssid,
        'passphrase': passphrase,
      });
      return result;
    } on PlatformException catch (e) {
      throw 'Failed to provision Wi-Fi: ${e.message}';
    }
  }

  // KBeacon Methods
  Future<String?> startScan() async {
    return await _channel.invokeMethod('startScan');
  }

  Future<void> connectToDevice(String macAddress, String password) async {
    try {
      await _channel.invokeMethod('connectToDevice', {
        'macAddress': macAddress,
        'password': password,
      });
    } on PlatformException catch (e) {
      throw 'Failed to connect to device: ${e.message}';
    }
  }

  Future<void> changeDeviceName(String newName) async {
    try {
      await _channel.invokeMethod('changeDeviceName', {'newName': newName});
    } on PlatformException catch (e) {
      throw 'Failed to change device name: ${e.message}';
    }
  }

  // Listen to scan results, scan failed, and BLE state changes
  Stream<List<String>> get scanResultsStream => _scanResultStream ?? Stream.empty();
  Stream<String> get scanFailedStream => _scanFailedStream ?? Stream.empty();
  Stream<String> get bleStateChangeStream => _bleStateChangeStream ?? Stream.empty();
}
