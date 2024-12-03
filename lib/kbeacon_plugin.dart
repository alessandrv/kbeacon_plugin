import 'dart:async';
import 'package:flutter/services.dart';
import 'bacon.dart';

class KbeaconPlugin {
  static const MethodChannel _methodChannel = MethodChannel('kbeacon_plugin');
  static const EventChannel _eventChannel = EventChannel('kbeacon_plugin_events');

  // Singleton pattern if desired
  static final KbeaconPlugin _instance = KbeaconPlugin._internal();

  factory KbeaconPlugin() {
    return _instance;
  }

  KbeaconPlugin._internal();

  // Start scanning for beacons
  Future<String?> startScan() async {
    try {
      final String? result = await _methodChannel.invokeMethod('startScan');
      return result;
    } on PlatformException catch (e) {
      throw 'Failed to start scan: ${e.message}';
    }
  }

  // Stop scanning for beacons
  Future<String?> stopScan() async {
    try {
      final String? result = await _methodChannel.invokeMethod('stopScan');
      return result;
    } on PlatformException catch (e) {
      throw 'Failed to stop scan: ${e.message}';
    }
  }

  // Connect to a specific beacon
  Future<void> connectToDevice(String macAddress, String password) async {
    try {
      await _methodChannel.invokeMethod('connectToDevice', {
        'macAddress': macAddress,
        'password': password,
      });
    } on PlatformException catch (e) {
      throw 'Failed to connect to device: ${e.message}';
    }
  }

  // Change the name of the connected device
  Future<void> changeDeviceName(String newName) async {
    try {
      await _methodChannel.invokeMethod('changeDeviceName', {'newName': newName});
    } on PlatformException catch (e) {
      throw 'Failed to change device name: ${e.message}';
    }
  }

  // Disconnect from the connected device
  Future<void> disconnectDevice() async {
    try {
      await _methodChannel.invokeMethod('disconnectDevice');
    } on PlatformException catch (e) {
      throw 'Failed to disconnect device: ${e.message}';
    }
  }

  // Stream of beacon scan results
  Stream<List<Beacon>> get scanResultsStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map && event['onScanResult'] != null) {
        List<dynamic> beaconList = event['onScanResult'];
        return beaconList
            .map((beaconMap) => Beacon.fromMap(Map<String, dynamic>.from(beaconMap)))
            .toList();
      }
      return [];
    });
  }

  // Stream of BLE state changes
  Stream<String> get bleStateStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map && event['onBleStateChange'] != null) {
        return event['onBleStateChange'] as String;
      }
      return 'unknown';
    });
  }

  // Optional: Combined event listener for multiple event types
  void listenToEvents({
    required Function(List<Beacon>) onScanResult,
    required Function(String) onBleStateChange,
    required Function(String) onScanFailed,
  }) {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        if (event['onScanResult'] != null) {
          List<dynamic> beaconList = event['onScanResult'];
          List<Beacon> beacons = beaconList
              .map((beaconMap) => Beacon.fromMap(Map<String, dynamic>.from(beaconMap)))
              .toList();
          onScanResult(beacons);
        }
        if (event['onBleStateChange'] != null) {
          String bleState = event['onBleStateChange'];
          onBleStateChange(bleState);
        }
        // Handle other event types if necessary
      }
    }, onError: (error) {
      onScanFailed(error.toString());
    });
  }

  // Additional methods as needed
}
