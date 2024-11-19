import Flutter
import UIKit
import CoreBluetooth
import ESPProvision

public class KbeaconPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var centralManager: CBCentralManager!
    private var peripherals: [CBPeripheral] = []
    private var scanPrefix: String = ""
    private var espDevice: ESPDevice?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = KbeaconPlugin()
        instance.methodChannel = FlutterMethodChannel(name: "kbeacon_plugin", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
        
        instance.eventChannel = FlutterEventChannel(name: "flutter_esp_ble_prov/scanBleDevices", binaryMessenger: registrar.messenger())
        instance.eventChannel?.setStreamHandler(instance)
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

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

    private func startScanning(withPrefix prefix: String) {
        guard centralManager.state == .poweredOn else {
            eventSink?(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is not powered on", details: nil))
            return
        }
        peripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func stopScanning() {
        centralManager.stopScan()
    }

    private func connectToDevice(uuid: String, result: @escaping FlutterResult) {
        guard let peripheral = peripherals.first(where: { $0.identifier.uuidString == uuid }) else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device not found", details: nil))
            return
        }

        ESPProvisionManager.shared.createESPDevice(deviceName: peripheral.name ?? "", transport: .ble) { device, error in
            if let device = device {
                self.espDevice = device
                result(true)
            } else if let error = error {
                result(FlutterError(code: "DEVICE_CREATION_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func provisionWifi(ssid: String, passphrase: String, result: @escaping FlutterResult) {
        espDevice?.provision(ssid: ssid, passPhrase: passphrase, completionHandler: { status in
            switch status {
            case .success:
                result(true)
            case .failure(let error):
                result(FlutterError(code: "PROVISION_FAILED", message: error.localizedDescription, details: nil))
            }
        })
    }

public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
        // Bluetooth is powered on and ready to use
        break
    case .poweredOff:
        eventSink?(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is turned off", details: nil))
    case .unauthorized:
        eventSink?(FlutterError(code: "BLUETOOTH_UNAUTHORIZED", message: "Bluetooth access is unauthorized", details: nil))
    case .unsupported:
        eventSink?(FlutterError(code: "BLUETOOTH_UNSUPPORTED", message: "Bluetooth is not supported on this device", details: nil))
    case .resetting:
        eventSink?(FlutterError(code: "BLUETOOTH_RESETTING", message: "Bluetooth is resetting", details: nil))
    case .unknown:
        eventSink?(FlutterError(code: "BLUETOOTH_UNKNOWN", message: "Bluetooth state is unknown", details: nil))
    @unknown default:
        eventSink?(FlutterError(code: "BLUETOOTH_UNKNOWN", message: "An unexpected Bluetooth state occurred", details: nil))
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
}
