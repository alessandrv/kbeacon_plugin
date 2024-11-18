import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart'; // For loading indicators
import 'package:wakelock_plus/wakelock_plus.dart';

class FiglioLogScreen extends StatefulWidget {
  @override
  _FiglioLogScreenState createState() => _FiglioLogScreenState();
}

class _FiglioLogScreenState extends State<FiglioLogScreen> with AutomaticKeepAliveClientMixin {
  // List to store advertisement data log entries
  List<String> advertisementLog = [];

  // Map to store last known messages for each device to prevent duplicates
  Map<String, String> lastKnownMessages = {};

  StreamSubscription? scanSubscription;
  ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true; // Keep the state alive when navigating away

  @override
  void initState() {
    WakelockPlus.enable(); // or WakelockPlus.toggle(on: false);

    super.initState();
    checkPermissionsAndStartScan();
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // or WakelockPlus.toggle(on: false);

    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> checkPermissionsAndStartScan() async {
    // Check platform and request permissions
    if (Platform.isAndroid) {
      await requestAndroidPermissions();
    } else if (Platform.isIOS) {
      // iOS permissions are handled in Info.plist
    }

    // Start scanning
    startScan();
  }

  Future<void> requestAndroidPermissions() async {
    // Request location permission if needed
    if (await Permission.location.isGranted != true) {
      await Permission.location.request();
    }

    // Request Bluetooth permissions (Android 12+)
    if (await Permission.bluetoothScan.isGranted != true) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isGranted != true) {
      await Permission.bluetoothConnect.request();
    }
  }

  void startScan() async {
    // Ensure Bluetooth is on
    BluetoothAdapterState adapterState = await FlutterBluePlus.adapterStateNow;
    if (adapterState != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please turn on Bluetooth')),
        );
        return;
      }
    }

    // Do not clear the advertisementLog here to preserve entries
    // If you want to clear it at some point, provide a separate method or UI control

    // Define the desired UUID in 128-bit format
    Guid desiredUUID = Guid('00002081-0000-1000-8000-00805f9b34fb');

    // Start scanning
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (var result in results) {
          // Check if the device advertises service data with the desired UUID
          if (result.advertisementData.serviceData.containsKey(desiredUUID)) {
            // Get the data associated with the service UUID '2081'
            List<int>? data = result.advertisementData.serviceData[desiredUUID];

            if (data != null && data.isNotEmpty) {
              // Convert data bytes to ASCII
              String asciiString = String.fromCharCodes(data);

              // Optional: Clean up non-printable characters
              asciiString = asciiString.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

              // Get the device ID (unique identifier)
              String deviceId = result.device.id.id; // Using device.id.id as unique identifier

              // Compare with last known message for this device to prevent duplicates
              if (lastKnownMessages[deviceId] != asciiString) {
                // Message has changed or is new, add to log
                String deviceName = result.device.name.isNotEmpty ? result.device.name : 'Dispositivo Sconosciuto';
                String logEntry = 'Dispositivo: $deviceName\n$asciiString';

                // Add to the advertisement log
                advertisementLog.add(logEntry);

                // Update the last known message
                lastKnownMessages[deviceId] = asciiString;

                // Optionally, limit the log size
                if (advertisementLog.length > 1000) {
                  advertisementLog.removeAt(0); // Remove the oldest entry
                }

                // Autoscroll to the bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              }
              // If the message is the same, do nothing
            }
          }
        }
      });
    }, onError: (error) {
      print('Scan error: $error');
      setState(() {
        // Optionally, handle scan errors here
      });
    });

    await FlutterBluePlus.startScan();
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    scanSubscription?.cancel();
    scanSubscription = null;
  }

  void clearLog() {
    setState(() {
      advertisementLog.clear();
      lastKnownMessages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Log dispositivi'),
        actions: [
          // Scan/Stop button
          StreamBuilder<bool>(
            stream: FlutterBluePlus.isScanning,
            initialData: false,
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return IconButton(
                  icon: SpinKitRipple(
                    color: Colors.white,
                    size: 24.0,
                  ),
                  onPressed: stopScan,
                  tooltip: 'Ferma scansione',
                );
              } else {
                return IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: startScan,
                  tooltip: 'Inizia Scansione',
                );
              }
            },
          ),
          // Clear log button
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: clearLog,
            tooltip: 'Pulisci log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Optional: Display Bluetooth state or any other status messages
          // For simplicity, it's omitted here
          Expanded(
            child: advertisementLog.isEmpty
                ? Center(
                    child: SpinKitRipple(
                        color: Colors.white,
                        size: 24.0,
                      ),
                  )
                : ListView.builder(
                    controller: _scrollController, // Attach the ScrollController
                    itemCount: advertisementLog.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Card(
                          color: Theme.of(context).splashColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Device Name
                                Text(
                                  advertisementLog[index].split('\n').first,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                // Data Value
                                Text(
                                  advertisementLog[index].split('\n').last,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
     
    );
  }

}