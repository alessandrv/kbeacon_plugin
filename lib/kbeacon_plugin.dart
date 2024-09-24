import 'package:flutter/services.dart';

class KbeaconPlugin {
  static const MethodChannel _channel = MethodChannel('kbeacon_plugin');

  // ESP BLE Provisioning Methods
  Future<void> scanBleDevices(String prefix) async {
    try {
      await _channel.invokeMethod('scanBleDevices', {'prefix': prefix});
    } on PlatformException catch (e) {
      throw 'Failed to scan BLE devices: ${e.message}';
    }
  }

  Future<void> scanWifiNetworks(String deviceName, String proofOfPossession) async {
    try {
      await _channel.invokeMethod('scanWifiNetworks', {
        'deviceName': deviceName,
        'proofOfPossession': proofOfPossession,
      });
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
