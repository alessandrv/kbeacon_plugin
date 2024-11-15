import 'package:flutter/material.dart';
import 'package:kbeacon_plugin/kbeacon_plugin.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart'; // Make sure to add the spinkit package
import 'WiFiSelectionScreen.dart';
import 'dart:async';

class DeviceSelectionScreen extends StatefulWidget {
  @override
  _DeviceSelectionScreenState createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  final _flutterEspBleProvPlugin = KbeaconPlugin();
  final prefixController = TextEditingController(text: 'PROV_');
  List<String> devices = [];
  String feedbackMessage = '';
  bool isScanning = false;
  StreamSubscription<String>? _scanSubscription;
  bool hasScanCompleted = false;

  @override
  void initState() {
    super.initState();
    _scanBleDevices();
  }

  Future<void> _scanBleDevices() async {
  _scanSubscription?.cancel();
  setState(() {
    devices.clear();
    isScanning = true;
    feedbackMessage = ''; // Clear any previous messages
    hasScanCompleted = false; // Reset the flag
  });

  final prefix = 'PROV';
  _scanSubscription = _flutterEspBleProvPlugin.scanBleDevicesAsStream(prefix).listen(
    (device) {
      print('Device found: $device');
      setState(() {
        if (!devices.contains(device)) {
          devices.add(device);
        }
      });
    },
    onDone: () {
      _completeScan('BLE scan completata');
    },
    onError: (error) {
      print('BLE scan error: $error');
      _completeScan('Errore durante la scansione dei dispositivi BLE: ${error.toString()}');
    },
  );
}
  void _completeScan(String message) {
    if (!hasScanCompleted) {
      hasScanCompleted = true;
      setState(() {
        isScanning = false;
        feedbackMessage = devices.isEmpty ? 'Nessun dispositivo trovato' : message;
      });
    }
  }

  void _selectDevice(String deviceName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WifiSelectionScreen(deviceName: deviceName),
      ),
    );
  }

  /// Builds the main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleziona un Dispositivo'),
        actions: [
          IconButton(
            icon: isScanning
                ? SpinKitCircle(
                    color: Theme.of(context).primaryColor,
                    size: 24.0,
                  )
                : const Icon(Icons.refresh),
            onPressed: isScanning ? null : _scanBleDevices, // Disable button if scanning
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: isScanning
                        ? SpinKitRipple(
                            color: Theme.of(context).primaryColor,
                          )
                        : feedbackMessage.isNotEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    feedbackMessage,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                ],
                              )
                            : const Text(
                                'Avvio della scansione BLE...',
                                style: TextStyle(fontSize: 16),
                              ),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          return _buildDeviceCard(devices[index]);
                        },
                      ),
                      if (isScanning)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: SpinKitRipple(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds a card widget for each BLE device
  Widget _buildDeviceCard(String deviceName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: GestureDetector(
        onTap: () => _selectDevice(deviceName),
        child: SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.bluetooth, size: 40, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      deviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
