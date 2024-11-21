// KbeaconPlugin.swift

import Flutter
import UIKit
import CoreBluetooth
import kbeaconlib2 // Ensure kbeaconlib2 is added via CocoaPods

@objc(KbeaconPlugin) // Exposes the class to Objective-C with the correct name
public class KbeaconPlugin: NSObject, FlutterPlugin {
    
    private var methodChannel: FlutterMethodChannel
    private var eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    
    private var beaconManager: KBeaconsMgr
    private var connectedBeacon: KBeacon?
    
    // To store method call results for asynchronous callbacks
    private var connectionResults: [String: FlutterResult] = [:]
    
    // Initialize with registrar
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = KbeaconPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
        registrar.addApplicationDelegate(instance) // Ensure the plugin receives app lifecycle events if needed
        instance.eventChannel.setStreamHandler(instance)
    }
    
    // Initializer
    init(registrar: FlutterPluginRegistrar) {
        self.methodChannel = FlutterMethodChannel(name: "kbeacon_plugin", binaryMessenger: registrar.messenger())
        self.eventChannel = FlutterEventChannel(name: "kbeacon_plugin_events", binaryMessenger: registrar.messenger())
        self.beaconManager = KBeaconsMgr.sharedBeaconManager
        super.init()
        self.beaconManager.delegate = self
    }
    
    // MARK: - FlutterPlugin Protocol Method
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startScan":
            self.startScan(result: result)
        case "connectToDevice":
            guard let args = call.arguments as? [String: Any],
                  let macAddress = args["macAddress"] as? String,
                  let password = args["password"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "macAddress and password are required", details: nil))
                return
            }
            self.connectToDevice(macAddress: macAddress, password: password, result: result)
        case "changeDeviceName":
            guard let args = call.arguments as? [String: Any],
                  let newName = args["newName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "newName is required", details: nil))
                return
            }
            self.changeDeviceName(newName: newName, result: result)
        case "disconnectDevice":
            self.disconnectDevice(result: result)
        // Add additional method cases here as needed
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension KbeaconPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

extension KbeaconPlugin: ConnStateDelegate {
    public func onConnStateChange(_ beacon: KBeacon, state: KBConnState, evt: KBConnEvtReason) {
        switch state {
        case .Connected:
            connectedBeacon = beacon
            if let mac = beacon.mac, let result = connectionResults[mac] {
                result("Connected to device \(mac)")
                connectionResults.removeValue(forKey: mac)
            }
            eventSink?(["connectionState": "connected", "macAddress": beacon.mac ?? ""])
        case .Disconnected:
            if let mac = beacon.mac, let result = connectionResults[mac] {
                result(FlutterError(code: "CONNECT_FAILED", message: "Failed to connect to device \(mac)", details: nil))
                connectionResults.removeValue(forKey: mac)
            }
            eventSink?(["connectionState": "disconnected", "macAddress": beacon.mac ?? ""])
        case .Connecting:
            eventSink?(["connectionState": "connecting", "macAddress": beacon.mac ?? ""])
        case .Disconnecting:
            eventSink?(["connectionState": "disconnecting", "macAddress": beacon.mac ?? ""])
        }
    }
}

extension KbeaconPlugin: KBeaconMgrDelegate {
    public func onBeaconDiscovered(beacons: [KBeacon]) {
        var beaconList: [[String: Any]] = []
        for beacon in beacons {
            let beaconInfo: [String: Any] = [
                "macAddress": beacon.mac ?? "",
                "rssi": beacon.rssi,
                "name": beacon.name ?? "Unknown"
            ]
            beaconList.append(beaconInfo)
        }
        eventSink?(["onScanResult": beaconList])
    }
    
    public func onCentralBleStateChange(newState: BLECentralMgrState) {
        // Map BLECentralMgrState to descriptive string or integer
        eventSink?(["bluetoothState": newState.rawValue])
    }
}

extension KbeaconPlugin: NotifyDataDelegate {
    public func onNotifyDataReceived(_ beacon: KBeacon, evt: Int, data: Data) {
        // Handle notify data and send to Flutter
        // You can parse the data as needed and send meaningful information
        let dataString = data.base64EncodedString()
        eventSink?([
            "onNotifyDataReceived": [
                "macAddress": beacon.mac ?? "",
                "event": evt,
                "data": dataString
            ]
        ])
    }
}

extension KbeaconPlugin {
    
    // Start scanning for KBeacon devices
    private func startScan(result: @escaping FlutterResult) {
        // Clear existing beacons
        beaconManager.clearBeacons()
        
        // Start scanning
        let scanStarted = beaconManager.startScanning()
        if scanStarted {
            result("Scan started successfully")
        } else {
            result(FlutterError(code: "SCAN_FAILED", message: "Failed to start scanning", details: nil))
        }
    }
    
    // Connect to a specific KBeacon device
    private func connectToDevice(macAddress: String, password: String, result: @escaping FlutterResult) {
        guard let beacon = beaconManager.beacons[macAddress] else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device with MAC \(macAddress) not found", details: nil))
            return
        }
        
        // Store the result to be called in the delegate
        connectionResults[macAddress] = result
        
        // Set self as the delegate to receive connection state changes
        beacon.delegate = self
        
        // Initiate connection
        // Removed 'password:' label to match method signature
        let connectSuccess = beacon.connect(password, timeout: 5000, delegate: self)
        if connectSuccess {
            result("Connecting to device \(macAddress)")
        } else {
            result(FlutterError(code: "CONNECT_INIT_FAILED", message: "Failed to initiate connection", details: nil))
        }
    }
    
    // Change the device name
    private func changeDeviceName(newName: String, result: @escaping FlutterResult) {
        guard let beacon = connectedBeacon, beacon.isConnected() else {
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
            return
        }
        
        // Create a common config with the new name
        let newConfig = KBCfgCommon()
        newConfig.setName(newName)
        
        // Modify the device config
        beacon.modifyConfig(array: [newConfig]) { success, error in
            if success {
                result("Device name changed to \(newName)")
            } else {
                // Changed 'error?.message' to 'error?.errorDescription'
                result(FlutterError(code: "NAME_CHANGE_FAILED", message: "Failed to change device name", details: error?.errorDescription))
            }
        }
    }
    
    // Disconnect from the connected device
    private func disconnectDevice(result: @escaping FlutterResult) {
        guard let beacon = connectedBeacon, beacon.isConnected() else {
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
            return
        }
        
        beacon.disconnect()
        connectedBeacon = nil
        result("Device disconnected")
    }
}
