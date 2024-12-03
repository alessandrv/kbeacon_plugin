import 'package:flutter/services.dart';

class KbeaconPlugin {
  static const MethodChannel _channel = MethodChannel('kbeacon_plugin');
  static const EventChannel _eventChannel = EventChannel('flutter_esp_ble_prov/scanBleDevices');

 // New method to start scanning for advertising messages
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

 void listenToScanResults(
      Function(List<String> beacons) onResult,
      Function(String errorMessage) onScanFailed,
      Function(String bleState) onBleStateChange) {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == "onScanResult") {
        List<String> beacons = List<String>.from(call.arguments);
        onResult(beacons);
      } else if (call.method == "onScanFailed") {
        String errorMessage = call.arguments as String;
        onScanFailed(errorMessage);
      } else if (call.method == "onBleStateChange") {
        String bleState = call.arguments as String;
        onBleStateChange(bleState);
      }
    });
  }
}