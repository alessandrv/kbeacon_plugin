import 'package:flutter/material.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import './WiFiSelectionScreen.dart';

class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({Key? key}) : super(key: key);

  @override
  _DeviceSelectionScreenState createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  final _flutterEspBleProvPlugin = FlutterEspBleProv();
  final prefixController = TextEditingController(text: 'PROV_');
  
  List<String> devices = [];
  String feedbackMessage = '';
  String selectedDeviceName = '';

  @override
  void initState() {
    super.initState();
    scanBleDevices();
  }

  Future<void> scanBleDevices() async {
    final prefix = prefixController.text;
    try {
      final scannedDevices = await _flutterEspBleProvPlugin.scanBleDevices(prefix);
      setState(() {
        devices = scannedDevices;
      });
    } catch (e) {
      // Handle error
    }
  }

  Widget _buildDeviceCard(String deviceName) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDeviceName = deviceName;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WifiSelectionScreen(deviceName: deviceName),
          ),
        );
      },
      child: Card(
        elevation: 4,
        color: Theme.of(context).splashColor,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Image.asset(
                  'assets/images/bluetooth_device.png', // Add a Bluetooth device image
                  width: double.infinity,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Select Device'),
        actions: [
          IconButton(
            icon: SpinKitRipple(
              color: Colors.white,
              size: 24.0,
            ),
            onPressed: scanBleDevices,
            tooltip: 'Refresh Scan',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: prefixController,
              decoration: InputDecoration(
                labelText: 'Device Prefix',
                labelStyle: const TextStyle(color: Colors.white),
                hintText: 'Enter device prefix',
                hintStyle: const TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  devices = [];
                });
              },
            ),
          ),
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Text(
                      'No devices found',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      return _buildDeviceCard(devices[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    prefixController.dispose();
    super.dispose();
  }
}