import Flutter
import UIKit
import CoreBluetooth
import ESPProvision
import kbeaconlib2

public class SwiftYourPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // Flutter communication channels
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    // Bluetooth and ESPProvision
    private var centralManager: CBCentralManager!
    private var peripherals: [CBPeripheral] = []
    private var scanPrefix: String = ""
    private var espDevice: ESPDevice?

    // Initialize plugin
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftYourPlugin()
        instance.methodChannel = FlutterMethodChannel(name: "kbeacon_plugin", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
        
        instance.eventChannel = FlutterEventChannel(name: "flutter_esp_ble_prov/scanBleDevices", binaryMessenger: registrar.messenger())
        instance.eventChannel?.setStreamHandler(instance)
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // Handle Flutter method calls
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scanBleDevices":
            if let args = call.arguments as? [String: Any], let prefix = args["prefix"] as? String {
                scanPrefix = prefix
                startScanning(withPrefix: prefix)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Prefix is missing", details: nil))
            }
        case "connectToDevice":
            if let args = call.arguments as? [String: Any], let uuid = args["uuid"] as? String {
                connectToDevice(uuid: uuid, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Device UUID is missing", details: nil))
            }
        case "provisionWifi":
            if let args = call.arguments as? [String: Any],
               let ssid = args["ssid"] as? String,
               let passphrase = args["passphrase"] as? String {
                provisionWifi(ssid: ssid, passphrase: passphrase, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Wi-Fi credentials are missing", details: nil))
            }
        case "stopScan":
            stopScanning()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Handle Flutter event stream
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        if let prefix = arguments as? String {
            startScanning(withPrefix: prefix)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopScanning()
        self.eventSink = nil
        return nil
    }

    // Start scanning for BLE devices
    private func startScanning(withPrefix prefix: String) {
        guard centralManager.state == .poweredOn else {
            eventSink?(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is not powered on", details: nil))
            return
        }
        peripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    // Stop scanning for BLE devices
    private func stopScanning() {
        centralManager.stopScan()
    }

    // Connect to a BLE device
    private func connectToDevice(uuid: String, result: @escaping FlutterResult) {
        guard let peripheral = peripherals.first(where: { $0.identifier.uuidString == uuid }) else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device not found", details: nil))
            return
        }
        centralManager.connect(peripheral, options: nil)
    }

    // Provision Wi-Fi to a connected device
    private func provisionWifi(ssid: String, passphrase: String, result: @escaping FlutterResult) {
        guard let espDevice = espDevice else {
            result(FlutterError(code: "DEVICE_NOT_CONNECTED", message: "No device connected", details: nil))
            return
        }

        espDevice.provision(ssid: ssid, passPhrase: passphrase, completionHandler: { status in
            switch status {
            case .success:
                result(true)
            case .failure(let error):
                result(FlutterError(code: "PROVISION_FAILED", message: error.localizedDescription, details: nil))
            }
        })
    }

    // CBCentralManagerDelegate methods
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            eventSink?(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is not powered on", details: nil))
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, name.hasPrefix(scanPrefix) {
            if !peripherals.contains(peripheral) {
                peripherals.append(peripheral)
                let deviceInfo: [String: Any] = [
                    "name": name,
                    "uuid": peripheral.identifier.uuidString,
                    "rssi": RSSI.intValue
                ]
                eventSink?(deviceInfo)
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        espDevice = ESPProvisionManager.shared.createESPDevice(peripheral: peripheral)
        espDevice?.connect { status in
            switch status {
            case .connected:
                self.methodChannel?.invokeMethod("onDeviceConnected", arguments: nil)
            case .disconnected:
                self.methodChannel?.invokeMethod("onDeviceDisconnected", arguments: nil)
            case .failed(let error):
                self.methodChannel?.invokeMethod("onConnectionFailed", arguments: error.localizedDescription)
            }
        }
    }
}
