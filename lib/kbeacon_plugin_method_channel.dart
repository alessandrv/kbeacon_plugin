import 'package:flutter/services.dart';
import 'kbeacon_plugin_platform_interface.dart';

class MethodChannelKbeaconPlugin extends KbeaconPluginPlatform {
  static const MethodChannel _channel = MethodChannel('kbeacon_plugin');

  @override
  Future<String?> startScan() async {
    return await _channel.invokeMethod('startScan');
  }

  @override
  void listenToScanResults(Function(List<String> beacons) onResult) {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == "onScanResult") {
        List<String> beacons = List<String>.from(call.arguments);
        onResult(beacons);
      }
    });
  }
}
