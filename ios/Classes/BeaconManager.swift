import Foundation
import CoreBluetooth
import Flutter

protocol BeaconManagerDelegate: AnyObject {
    func onBeaconDiscovered(beacons: [String])
    func onScanFailed(error: String)
    func onBleStateChange(state: String)
    // Add more delegate methods as needed
}

class BeaconManager: NSObject, FlutterStreamHandler {
    weak var delegate: BeaconManagerDelegate?
    
    private var centralManager: CBCentralManager!
    private var discoveredBeacons: [CBPeripheral] = []
    private var connectedPeripheral: CBPeripheral?
    private var connectionPassword: String?
    private var methodResult: FlutterResult?
    
    // Device Name Change Properties
    private var nameChangeResult: FlutterResult?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Beacon Scanning Methods
    
    func startScanning(result: @escaping FlutterResult) {
        self.methodResult = result
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            result("Scan started successfully")
        } else {
            result(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is not powered on", details: nil))
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    // MARK: - Beacon Connection Methods
    
    func connectToDevice(macAddress: String, password: String, result: @escaping FlutterResult) {
        // Note: iOS does not provide direct access to MAC addresses.
        // Use peripheral identifiers or other identifiers to connect.
        // This is a placeholder implementation.
        
        // Find peripheral by identifier or other means
        guard let peripheral = discoveredBeacons.first(where: { $0.identifier.uuidString.lowercased() == macAddress.lowercased() }) else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Could not find device with ID: \(macAddress)", details: nil))
            return
        }
        
        self.connectedPeripheral = peripheral
        self.connectionPassword = password
        centralManager.connect(peripheral, options: nil)
        result(nil)
    }
    
    func disconnectDevice(result: @escaping FlutterResult) {
        guard let peripheral = connectedPeripheral else {
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
            return
        }
        centralManager.cancelPeripheralConnection(peripheral)
        connectedPeripheral = nil
        result("Device disconnected")
    }
    
    func changeDeviceName(newName: String, result: @escaping FlutterResult) {
        guard let peripheral = connectedPeripheral else {
            result(FlutterError(code: "NO_CONNECTED_DEVICE", message: "No device is connected", details: nil))
            return
        }
        
        // iOS does not allow changing the peripheral's name directly.
        // You need to write to a specific characteristic that handles name changes.
        // This is a placeholder implementation.
        
        // Example:
        // 1. Identify the characteristic responsible for name changes
        // 2. Write the new name to that characteristic
        
        // Placeholder:
        nameChangeResult = result
        // Implement the write operation here
        result("Device name changed to \(newName)") // Placeholder
    }
    
    // MARK: - FlutterStreamHandler Methods
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Not used as we are using delegate to send events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopScanning()
        return nil
    }
}

extension BeaconManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Ready to scan
            break
        case .poweredOff:
            delegate?.onScanFailed(error: "Bluetooth is powered off")
        case .unsupported:
            delegate?.onScanFailed(error: "Bluetooth is unsupported on this device")
        case .unauthorized:
            delegate?.onScanFailed(error: "Bluetooth unauthorized")
        case .resetting:
            delegate?.onScanFailed(error: "Bluetooth is resetting")
        case .unknown:
            delegate?.onScanFailed(error: "Bluetooth state is unknown")
        @unknown default:
            delegate?.onScanFailed(error: "Bluetooth state is unknown")
        }
        
        delegate?.onBleStateChange(state: "Bluetooth state changed: \(central.state.rawValue)")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Identify beacons based on advertisement data
        // This may involve checking specific service UUIDs or manufacturer data
        let beaconInfo = "ID: \(peripheral.identifier.uuidString), RSSI: \(RSSI), Name: \(peripheral.name ?? "Unknown")"
        
        if !discoveredBeacons.contains(peripheral) {
            discoveredBeacons.append(peripheral)
            delegate?.onBeaconDiscovered(beacons: [beaconInfo])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Handle successful connection
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.onScanFailed(error: "Failed to connect to device: \(peripheral.name ?? "Unknown")")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            delegate?.onScanFailed(error: "Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            delegate?.onScanFailed(error: "Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            // Identify characteristics based on UUIDs
            // Implement your beacon operations here
        }
    }
    
    // Implement other CBPeripheralDelegate methods as needed
}
