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
        registrar.addApplicationDelegate(instance)
        instance.eventChannel.setStreamHandler(instance) // Ensure this matches Flutter
        print("KbeaconPlugin registered with Flutter")
    }
    
    // Update the initializer to use the correct channel name
    init(registrar: FlutterPluginRegistrar) {
        self.methodChannel = FlutterMethodChannel(name: "kbeacon_plugin", binaryMessenger: registrar.messenger())
        self.eventChannel = FlutterEventChannel(name: "flutter_esp_ble_prov/scanBleDevices", binaryMessenger: registrar.messenger()) // Updated name
        self.beaconManager = KBeaconsMgr.sharedBeaconManager
        super.init()
        self.beaconManager.delegate = self
        print("KbeaconPlugin initialized")
    }
    
    // MARK: - FlutterPlugin Protocol Method
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("Received method call: \(call.method)")
        switch call.method {
        case "startScan":
            self.startScan(result: result)
        case "connectToDevice":
            guard let args = call.arguments as? [String: Any],
                  let macAddress = args["macAddress"] as? String,
                  let password = args["password"] as? String else {
                print("Invalid arguments for connectToDevice")
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "macAddress and password are required", details: nil))
                return
            }
            self.connectToDevice(macAddress: macAddress, password: password, result: result)
        case "changeDeviceName":
            guard let args = call.arguments as? [String: Any],
                  let newName = args["newName"] as? String else {
                print("Invalid arguments for changeDeviceName")
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "newName is required", details: nil))
                return
            }
            self.changeDeviceName(newName: newName, result: result)
        case "disconnectDevice":
            self.disconnectDevice(result: result)
        // Add additional method cases here as needed
        default:
            print("Method not implemented: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
}

extension KbeaconPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("Event channel onListen called")
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("Event channel onCancel called")
        self.eventSink = nil
        return nil
    }
}

extension KbeaconPlugin: ConnStateDelegate {
    public func onConnStateChange(_ beacon: KBeacon, state: KBConnState, evt: KBConnEvtReason) {
        print("Connection state changed: \(state.rawValue), Event: \(evt.rawValue)")
        switch state {
        case .Connected:
            connectedBeacon = beacon
            if let mac = beacon.mac, let result = connectionResults[mac] {
                print("Successfully connected to device \(mac)")
                result("Connected to device \(mac)")
                connectionResults.removeValue(forKey: mac)
            }
            eventSink?(["connectionState": "connected", "macAddress": beacon.mac ?? ""])
        case .Disconnected:
            if let mac = beacon.mac, let result = connectionResults[mac] {
                print("Failed to connect to device \(mac)")
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
<<<<<<< HEAD
       public func onBeaconDiscovered(beacons: [KBeacon]) {
=======
     public func onBeaconDiscovered(beacons: [KBeacon]) {
>>>>>>> 68b227f8fbfab1383fb9fe9be1827a0a6939fd34
        print("Beacons discovered: \(beacons.count)")
        var beaconList: [String] = []
        
        for beacon in beacons {
            let mac = beacon.mac ?? "unknown"
            let rssi = beacon.rssi
            let name = beacon.name ?? "Unknown"
            
            // Format beacon info string to match Android format
            let beaconInfo = "MAC: \(mac), RSSI: \(rssi), Name: \(name)"
            beaconList.append(beaconInfo)
            
            print("Discovered Beacon: \(beaconInfo)")
        }
        
        // Send array of strings through event sink
        eventSink?(["onScanResult": beaconList])
    }
    
    
    public func onCentralBleStateChange(newState: BLECentralMgrState) {
        print("BLE Central Manager state changed: \(newState.rawValue)")
        let stateMessage = "Bluetooth state changed: \(newState.rawValue)"
        eventSink?(["onBleStateChange": stateMessage])
    }
}

extension KbeaconPlugin: NotifyDataDelegate {
    public func onNotifyDataReceived(_ beacon: KBeacon, evt: Int, data: Data) {
        let dataString = data.base64EncodedString()
        print("Notify data received from \(beacon.mac ?? ""): Event \(evt), Data \(dataString)")
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
        print("Starting scan for beacons")
        // Clear existing beacons
        beaconManager.clearBeacons()
        
        // Start scanning
        let scanStarted = beaconManager.startScanning()
        if scanStarted {
            print("Scan started successfully")
            result("Scan started successfully")
        } else {
            print("Failed to start scanning")
            result(FlutterError(code: "SCAN_FAILED", message: "Failed to start scanning", details: nil))
        }
    }
    
    // Connect to a specific KBeacon device
    private func connectToDevice(macAddress: String, password: String, result: @escaping FlutterResult) {
        print("Attempting to connect to device \(macAddress) with password \(password)")
        guard let beacon = beaconManager.beacons[macAddress] else {
            print("Device with MAC \(macAddress) not found")
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device with MAC \(macAddress) not found", details: nil))
            return
        }
        
        // Store the result to be called in the delegate
        connectionResults[macAddress] = result
        
        // Set self as the delegate to receive connection state changes
        beacon.delegate = self
        
        // Initiate connection
        let connectSuccess = beacon.connect(password, timeout: 5000, delegate: self)
        print("Connection initiation success: \(connectSuccess)")
        if connectSuccess {
            print("Initiated connection to device \(macAddress)")
            result("Connecting to device \(macAddress)")
        } else {
            print("Failed to initiate connection to device \(macAddress)")
            result(FlutterError(code: "CONNECT_INIT_FAILED", message: "Failed to initiate connection", details: nil))
        }
    }
    
    // Change the device name
    private func changeDeviceName(newName: String, result: @escaping FlutterResult) {
        print("Changing device name to \(newName)")
        guard let beacon = connectedBeacon, beacon.isConnected() else {
            print("No connected device to change name")
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
            return
        }
        
        // Create a common config with the new name
        let newConfig = KBCfgCommon()
        newConfig.setName(newName)
        
        // Modify the device config
        beacon.modifyConfig(array: [newConfig]) { success, error in
            if success {
                print("Device name changed to \(newName)")
                result("Device name changed to \(newName)")
            } else {
                print("Failed to change device name: \(error?.errorDescription ?? "Unknown error")")
                result(FlutterError(code: "NAME_CHANGE_FAILED", message: "Failed to change device name", details: error?.errorDescription))
            }
        }
    }
    
    // Disconnect from the connected device
    private func disconnectDevice(result: @escaping FlutterResult) {
        print("Attempting to disconnect device")
        guard let beacon = connectedBeacon, beacon.isConnected() else {
            print("No connected device to disconnect")
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
            return
        }
        
        beacon.disconnect()
        connectedBeacon = nil
        print("Device disconnected")
        result("Device disconnected")
    }
}
