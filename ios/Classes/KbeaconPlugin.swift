// ios/Classes/MyPlugin.swift

import Flutter
import UIKit
import kbeaconlib2

public class KbeaconPlugin: NSObject, FlutterPlugin, KBeaconMgrDelegate {
    
    private var methodChannel: FlutterMethodChannel
    private var eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    
    private var kBeaconsMgr: KBeaconsMgr?
    private var connectedBeacon: KBeacon?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = KbeaconPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
    }
    
    init(registrar: FlutterPluginRegistrar) {
        self.methodChannel = FlutterMethodChannel(name: "kbeacon_plugin", binaryMessenger: registrar.messenger())
        self.eventChannel = FlutterEventChannel(name: "kbeacon_plugin_events", binaryMessenger: registrar.messenger())
        super.init()
        self.methodChannel.setMethodCallHandler(handle)
        
        self.eventChannel.setStreamHandler(self)
        
        self.kBeaconsMgr = KBeaconsMgr.sharedBeaconManager()
        self.kBeaconsMgr?.delegate = self
    }
    
    deinit {
        self.kBeaconsMgr?.delegate = nil
    }
    
    // Handle Method Calls
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startScan":
            startKBeaconScan(result: result)
        case "connectToDevice":
            if let args = call.arguments as? [String: Any],
               let macAddress = args["macAddress"] as? String,
               let password = args["password"] as? String {
                connectToKBeaconDevice(macAddress: macAddress, password: password, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing macAddress or password", details: nil))
            }
        case "changeDeviceName":
            if let args = call.arguments as? [String: Any],
               let newName = args["newName"] as? String {
                changeKBeaconDeviceName(newName: newName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing newName", details: nil))
            }
        case "disconnectDevice":
            disconnectFromKBeaconDevice(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // Permission Handling
    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        // iOS handles permissions differently. Ensure you have the required keys in Info.plist
        // such as NSBluetoothAlwaysUsageDescription and NSLocationWhenInUseUsageDescription
        
        // Check Bluetooth authorization
        if #available(iOS 13.0, *) {
            let status = CBManager.authorization
            switch status {
            case .allowedAlways:
                completion(true)
            case .denied, .restricted:
                completion(false)
            case .notDetermined:
                // Bluetooth permissions are requested automatically when starting a scan
                completion(true)
            @unknown default:
                completion(false)
            }
        } else {
            // Fallback for older iOS versions
            completion(true)
        }
    }
    
    // KBeacon Methods
    private func startKBeaconScan(result: @escaping FlutterResult) {
        requestPermissions { granted in
            if granted {
                let scanResult = self.kBeaconsMgr?.startScanning()
                if scanResult == 0 {
                    result("Scan started successfully")
                } else {
                    result(FlutterError(code: "SCAN_FAILED", message: "Failed to start scanning", details: nil))
                }
            } else {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Required permissions not granted", details: nil))
            }
        }
    }
    
    private func disconnectFromKBeaconDevice(result: @escaping FlutterResult) {
        if let beacon = connectedBeacon, beacon.isConnected() {
            beacon.disconnect()
            connectedBeacon = nil
            result("Device disconnected")
        } else {
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
        }
    }
    
    private func connectToKBeaconDevice(macAddress: String, password: String, result: @escaping FlutterResult) {
        guard let beacon = kBeaconsMgr?.getBeacon(macAddress) else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Could not find device with MAC: \(macAddress)", details: nil))
            return
        }
        
        beacon.connect(password: password, timeout: 5000) { [weak self] state, reason in
            guard let self = self else { return }
            if state == .connected {
                self.connectedBeacon = beacon
                result("Connected to \(macAddress)")
            } else if state == .disconnected {
                result(FlutterError(code: "CONNECT_FAILED", message: "Failed to connect to device", details: nil))
            }
        }
    }
    
    private func changeKBeaconDeviceName(newName: String, result: @escaping FlutterResult) {
        guard let beacon = connectedBeacon, beacon.isConnected() else {
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
            return
        }
        
        let commonConfig = KBCfgCommon()
        commonConfig.name = newName
        
        let configList: [KBCfgBase] = [commonConfig]
        
        beacon.modifyConfig(configList: configList) { success, error in
            if success {
                result("Device name changed to \(newName)")
                
                // Disconnect after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if beacon.isConnected() {
                        beacon.disconnect()
                    }
                }
            } else {
                result(FlutterError(code: "NAME_CHANGE_FAILED", message: "Failed to change device name", details: error?.localizedDescription))
            }
        }
    }
    
    // KBeaconMgrDelegate Methods
    public func onBeaconDiscovered(beacons: [KBeacon]) {
        var beaconList: [[String: Any]] = []
        for beacon in beacons {
            let beaconInfo: [String: Any] = [
                "mac": beacon.mac,
                "rssi": beacon.rssi,
                "name": beacon.name
            ]
            beaconList.append(beaconInfo)
        }
        eventSink?(["onScanResult": beaconList])
    }
    
    public func onScanFailed(errorCode: Int) {
        let errorMessage = "Scan failed with error code: \(errorCode)"
        eventSink?(["onScanFailed": errorMessage])
    }
    
    public func onCentralBleStateChange(bleState: Int) {
        let bleStateMessage = "Bluetooth state changed: \(bleState)"
        eventSink?(["onBleStateChange": bleStateMessage])
    }
}

extension KbeaconPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
