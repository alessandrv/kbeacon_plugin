import 'package:flutter_test/flutter_test.dart';
import 'package:kbeacon_plugin/kbeacon_plugin.dart';
import 'package:kbeacon_plugin/kbeacon_plugin_platform_interface.dart';
import 'package:kbeacon_plugin/kbeacon_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockKbeaconPluginPlatform
    with MockPlatformInterfaceMixin
    implements KbeaconPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final KbeaconPluginPlatform initialPlatform = KbeaconPluginPlatform.instance;

  test('$MethodChannelKbeaconPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelKbeaconPlugin>());
  });

  test('getPlatformVersion', () async {
    KbeaconPlugin kbeaconPlugin = KbeaconPlugin();
    MockKbeaconPluginPlatform fakePlatform = MockKbeaconPluginPlatform();
    KbeaconPluginPlatform.instance = fakePlatform;

    expect(await kbeaconPlugin.getPlatformVersion(), '42');
  });
}
