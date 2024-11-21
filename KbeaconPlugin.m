#import "KbeaconPlugin.h"
import KBeaconSDK

@implementation KbeaconPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"kbeacon_plugin"
            binaryMessenger:[registrar messenger]];
  KbeaconPlugin* instance = [[KbeaconPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@objc func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "startScan" {
        // Start KBeacon scan using the iOS SDK
        result("Scan started")
    }
}
@end
