import Flutter
import UIKit
import CoreBluetooth
import kbeaconlib2
import ESPProvision
import EventBusSwift

public class KbeaconPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, KBeaconMgrDelegate, CBCentralManagerDelegate {
    
    private var methodChannel: FlutterMethodChannel
    private var eventChannel: FlutterEventChannel
    private var bleScanEventSink: FlutterEventSink?
    
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [CBPeripheral] = []
    
    private var espProvisionManager: ESPProvisionManager!
    private var kBeaconsMgr: KBeaconsMgr!
    private var connectedBeacon: KBeacon?
    
    private var bleDevices: [String: KBeacon] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "kbeacon_plugin", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "flutter_esp_ble_prov/scanBleDevices", binaryMessenger: registrar.messenger())
        let instance = KbeaconPlugin(methodChannel: methodChannel, eventChannel: eventChannel)
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    init(methodChannel: FlutterMethodChannel, eventChannel: FlutterEventChannel) {
        self.methodChannel = methodChannel
        self.eventChannel = eventChannel
        super.init()
        
        // Initialize Central Manager for BLE
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        
        // Initialize ESP Provision Manager
        espProvisionManager = ESPProvisionManager.shared
        
        // Initialize KBeacons Manager
        kBeaconsMgr = KBeaconsMgr.sharedBeaconManager()
        kBeaconsMgr.delegate = self
    }
    
    // MARK: - FlutterStreamHandler Methods
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.bleScanEventSink = events
        if let prefix = arguments as? String {
            startBleScan(prefix: prefix)
        } else {
            startBleScan(prefix: "")
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopScan()
        self.bleScanEventSink = nil
        return nil
    }
    
    // MARK: - FlutterPlugin Method Call Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scanBleDevices":
            let prefix = call.arguments as? String ?? ""
            scanBleDevices(prefix: prefix, result: result)
        case "scanWifiNetworks":
            guard let args = call.arguments as? [String: Any],
                  let deviceName = args["deviceName"] as? String,
                  let pop = args["proofOfPossession"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for scanWifiNetworks", details: nil))
                return
            }
            scanWifiNetworks(deviceName: deviceName, proofOfPossession: pop, result: result)
        case "provisionWifi":
            guard let args = call.arguments as? [String: Any],
                  let deviceName = args["deviceName"] as? String,
                  let pop = args["proofOfPossession"] as? String,
                  let ssid = args["ssid"] as? String,
                  let passphrase = args["passphrase"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for provisionWifi", details: nil))
                return
            }
            provisionWifi(deviceName: deviceName, proofOfPossession: pop, ssid: ssid, passphrase: passphrase, result: result)
        case "startScan":
            startKBeaconScan(result: result)
        case "connectToDevice":
            guard let args = call.arguments as? [String: Any],
                  let macAddress = args["macAddress"] as? String,
                  let password = args["password"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for connectToDevice", details: nil))
                return
            }
            connectToKBeaconDevice(macAddress: macAddress, password: password, result: result)
        case "changeDeviceName":
            guard let args = call.arguments as? [String: Any],
                  let newName = args["newName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for changeDeviceName", details: nil))
                return
            }
            changeKBeaconDeviceName(newName: newName, result: result)
        case "disconnectDevice":
            disconnectFromKBeaconDevice(result: result)
        case "stopScan":
            stopScan()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - BLE Scanning
    
    private func scanBleDevices(prefix: String, result: @escaping FlutterResult) {
        // Request permissions before scanning
        requestPermissions { granted in
            if granted {
                self.startBleScan(prefix: prefix)
                result(nil)
            } else {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Required permissions not granted", details: nil))
            }
        }
    }
    
    private func startBleScan(prefix: String) {
        // Define the service UUID if needed
        let serviceUUIDs: [CBUUID]? = [CBUUID(string: "00002080-0000-1000-8000-00805F9B34FB")] // Replace with actual UUID if needed
        
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        print("Started BLE scan with prefix: \(prefix)")
    }
    
    private func stopScan() {
        kBeaconsMgr.stopScanning()
        print("Stopped BLE scan")
    }
    
    // MARK: - CBCentralManagerDelegate Methods
    
    @objc public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            // Optionally, start scanning automatically
        case .poweredOff:
            print("Bluetooth is powered off")
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("A new Bluetooth state is available")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Filter based on prefix if needed
        let deviceName = peripheral.name ?? "Unknown"
        if deviceName.hasPrefix(prefixFilter(prefix: "")) { // Replace "" with actual prefix if needed
            // Process the scan record
            if let scanRecordData = advertisementData[CBAdvertisementDataServiceDataKey] as? [String: Any] {
                // Extract service data
                // Process scanRecordData as needed
            }
            
            // Log device info
            print("Discovered Device: \(deviceName), RSSI: \(RSSI)")
            
            // Send to Flutter
            let message = "Device: \(deviceName), RSSI: \(RSSI), AdvertisementData: \(advertisementData)"
            bleScanEventSink?(message)
            
            // Optionally, store the peripheral
            // Here, assuming that `kBeaconsMgr` will handle beacon discovery
        }
    }
    
    // Helper method for prefix filtering (if needed)
    private func prefixFilter(prefix: String) -> String {
        return prefix
    }
    
    // MARK: - Permissions Handling
    
    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        // iOS handles permissions automatically when starting scans
        // You can check authorization status if needed
        // For simplicity, assume permissions are granted
        completion(true)
    }
    
    // MARK: - ESP BLE Provisioning Methods
    
    private func scanWifiNetworks(deviceName: String, proofOfPossession: String, result: @escaping FlutterResult) {
        guard let beacon = bleDevices[deviceName],
              let peripheral = beacon.cbPeripheral,
              let serviceUUID = beacon.serviceUUID else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device or Service UUID not found", details: nil))
            return
        }
        
        // Create ESPDevice
        let espDevice = espProvisionManager.createESPDevice(deviceName: deviceName, transport: .blePeripheral, security: .security1)
        
        // Subscribe to DeviceConnectionEvent
        EventBus.on(self, name: "DeviceConnectionEvent") { [weak self] (event: DeviceConnectionEvent) in
            guard let self = self else { return }
            // Handle the event
            if let deviceEvent = event as? DeviceConnectionEvent {
                switch deviceEvent.eventType {
                case .connected:
                    // Set proof of possession
                    espDevice.setProofOfPossession(proofOfPossession)
                    
                    // Scan for Wi-Fi networks
                    espDevice.scanNetworks { wifiList, error in
                        if let error = error as? KBException {
                            result(FlutterError(code: "WIFI_SCAN_FAILED", message: "Wi-Fi scan failed", details: error.localizedDescription))
                            espDevice.disconnectDevice()
                            return
                        }
                        
                        guard let wifiList = wifiList else {
                            result(FlutterError(code: "WIFI_SCAN_FAILED", message: "Wi-Fi scan returned no results", details: nil))
                            espDevice.disconnectDevice()
                            return
                        }
                        
                        let ssidList = wifiList.map { $0.wifiName }
                        result(ssidList)
                        espDevice.disconnectDevice()
                    }
                case .disconnected:
                    result(FlutterError(code: "DEVICE_DISCONNECTED", message: "Device disconnected", details: nil))
                case .connectionFailed:
                    result(FlutterError(code: "CONNECTION_FAILED", message: "Failed to connect to device", details: nil))
                }
            }
        }
        
        // Start the connection
        espDevice.connectBLEDevice(peripheral: peripheral, serviceUUID: serviceUUID) { success, error in
            if !success, let error = error {
                result(FlutterError(code: "CONNECTION_FAILED", message: "Failed to connect to device", details: error.localizedDescription))
            }
        }
    }
    
    private func provisionWifi(deviceName: String, proofOfPossession: String, ssid: String, passphrase: String, result: @escaping FlutterResult) {
        guard let beacon = bleDevices[deviceName],
              let peripheral = beacon.cbPeripheral,
              let serviceUUID = beacon.serviceUUID else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device or Service UUID not found", details: nil))
            return
        }
        
        // Create ESPDevice
        let espDevice = espProvisionManager.createESPDevice(deviceName: deviceName, transport: .blePeripheral, security: .security1)
        
        // Subscribe to DeviceConnectionEvent
        EventBus.on(self, name: "DeviceConnectionEvent") { [weak self] (event: DeviceConnectionEvent) in
            guard let self = self else { return }
            // Handle the event
            if let deviceEvent = event as? DeviceConnectionEvent {
                switch deviceEvent.eventType {
                case .connected:
                    // Set proof of possession
                    espDevice.setProofOfPossession(proofOfPossession)
                    
                    // Proceed with provisioning
                    espDevice.provision(ssid: ssid, passphrase: passphrase) { success, error in
                        if let error = error as? KBException {
                            result(FlutterError(code: "PROVISION_FAILED", message: "Provisioning failed", details: error.localizedDescription))
                            espDevice.disconnectDevice()
                            return
                        }
                        
                        if success {
                            result(true)
                            espDevice.disconnectDevice()
                        } else {
                            result(FlutterError(code: "PROVISION_FAILED", message: "Provisioning failed", details: "Unknown error"))
                            espDevice.disconnectDevice()
                        }
                    }
                case .disconnected:
                    result(FlutterError(code: "DEVICE_DISCONNECTED", message: "Device disconnected", details: nil))
                case .connectionFailed:
                    result(FlutterError(code: "CONNECTION_FAILED", message: "Failed to connect to device", details: nil))
                }
            }
        }
        
        // Start the connection
        espDevice.connectBLEDevice(peripheral: peripheral, serviceUUID: serviceUUID) { success, error in
            if !success, let error = error {
                result(FlutterError(code: "CONNECTION_FAILED", message: "Failed to connect to device", details: error.localizedDescription))
            }
        }
    }
    
    // MARK: - KBeacon Methods
    
    private func startKBeaconScan(result: @escaping FlutterResult) {
        let scanResult = kBeaconsMgr.startScanning()
        if scanResult {
            result("Scan started successfully")
        } else {
            result(FlutterError(code: "SCAN_FAILED", message: "Failed to start scanning", details: nil))
        }
    }
    
    private func disconnectFromKBeaconDevice(result: @escaping FlutterResult) {
        if let beacon = connectedBeacon, beacon.isConnected {
            beacon.disconnect()
            connectedBeacon = nil
            result("Device disconnected")
        } else {
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
        }
    }
    
    private func connectToKBeaconDevice(macAddress: String, password: String, result: @escaping FlutterResult) {
        guard let beacon = kBeaconsMgr.getBeacon(macAddress),
              let peripheral = beacon.cbPeripheral,
              let serviceUUID = beacon.serviceUUID else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Could not find device with MAC: \(macAddress)", details: nil))
            return
        }
        
        beacon.connect(password: password, timeout: 5000) { [weak self] (state: KBConnState, evt: KBConnEvtReason) in
            guard let self = self else { return }
            if state == .Connected {
                self.connectedBeacon = beacon
                result("Connected to \(macAddress)")
            } else if state == .Disconnected {
                result(FlutterError(code: "CONNECT_FAILED", message: "Failed to connect to device", details: nil))
            }
        }
    }
    
    private func changeKBeaconDeviceName(newName: String, result: @escaping FlutterResult) {
        guard let beacon = connectedBeacon, beacon.isConnected else {
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
            return
        }
        
        let commonConfig = KBCfgCommon()
        commonConfig.setName(newName)
        
        let configList: [KBCfgBase] = [commonConfig]
        
        beacon.modifyConfig(array: configList) { [weak self] success, error in
            guard let self = self else { return }
            if success {
                result("Device name changed to \(newName)")
                // Optionally, disconnect after a delay if needed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    beacon.disconnect()
                }
            } else {
                if let kbException = error as? KBException {
                    result(FlutterError(code: "NAME_CHANGE_FAILED", message: "Failed to change device name", details: kbException.localizedDescription))
                } else {
                    result(FlutterError(code: "NAME_CHANGE_FAILED", message: "Failed to change device name", details: "Unknown error"))
                }
            }
        }
    }
    
    // MARK: - KBeaconMgrDelegate Methods
    
    public func onBeaconDiscovered(beacons: [KBeacon]) {
        var beaconList: [String] = []
        for beacon in beacons {
            let beaconInfo = "MAC: \(beacon.mac ?? "Unknown"), RSSI: \(beacon.rssi), Name: \(beacon.name ?? "Unknown")"
            beaconList.append(beaconInfo)
            // Store discovered beacons
            if let mac = beacon.mac {
                bleDevices[mac] = beacon
            }
        }
        methodChannel.invokeMethod("onScanResult", arguments: beaconList)
    }
    
    public func onScanFailed(errorCode: Int) {
        let errorMessage = "Scan failed with error code: \(errorCode)"
        methodChannel.invokeMethod("onScanFailed", arguments: errorMessage)
    }
    
    public func onCentralBleStateChange(newState: BLECentralMgrState) {
        let bleStateMessage: String
        switch newState {
        case .PowerOn:
            bleStateMessage = "Bluetooth is Powered On"
        case .PowerOff:
            bleStateMessage = "Bluetooth is Powered Off"
        case .Unauthorized:
            bleStateMessage = "Bluetooth is Unauthorized"
        case .Unknown:
            bleStateMessage = "Bluetooth State is Unknown"
        }
        methodChannel.invokeMethod("onBleStateChange", arguments: bleStateMessage)
    }
    
    // MARK: - Additional Methods
    
    // Example: Show dialog message via Flutter
    private func showDialogMsg(title: String, message: String) {
        let args: [String: Any] = ["title": title, "message": message]
        methodChannel.invokeMethod("showDialog", arguments: args)
    }
    
    // Example: Get localized string (Implement as needed)
    private func getString(_ key: String) -> String {
        // Implement localization as needed or return key
        return key
    }
    
    // You can add more helper methods as needed
}
