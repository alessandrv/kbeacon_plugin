import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'kbeacon_plugin_method_channel.dart';

abstract class KbeaconPluginPlatform extends PlatformInterface {
  /// Constructs a KbeaconPluginPlatform.
  KbeaconPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static KbeaconPluginPlatform _instance = MethodChannelKbeaconPlugin();

  /// The default instance of [KbeaconPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelKbeaconPlugin].
  static KbeaconPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [KbeaconPluginPlatform] when
  /// they register themselves.
  static set instance(KbeaconPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }


  Future<String?> startScan();
  void listenToScanResults(Function(List<String> beacons) onResult);




}
