import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:kbeacon_plugin_example/screens/FiglioLogScreen.dart';
import 'package:kbeacon_plugin_example/utils/notification_helper.dart';
import 'package:permission_handler/permission_handler.dart'; // Import FiglioLogScreen

class LedControlScreen extends StatefulWidget {
  @override
  _LedControlScreenState createState() => _LedControlScreenState();
}

class _LedControlScreenState extends State<LedControlScreen> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? ledCharacteristic;
  List<Map<String, dynamic>> devices = [];

  StreamSubscription<List<ScanResult>>? scanSubscription;

  TimeOfDay selectedTime = TimeOfDay.now(); // Class-level variable

  @override
  void initState() {
    super.initState();
    scanDevices(); // Start scanning automatically when the page opens
  }

  @override
  void dispose() {
    scanSubscription?.cancel(); // Cancel the scan subscription
    FlutterBluePlus.stopScan(); // Stop scanning
    connectedDevice?.disconnect(); // Disconnect from the device
    super.dispose();
  }

void _showErrorDialog(String message) {
      showNotification(context, message, false);

}


  void scanDevices() async {
    try {
      Guid desiredUUID = Guid('00002082-0000-1000-8000-00805f9b34fb');
      setState(() {
        devices.clear();
      });

      // Start scanning with a timeout of 10 seconds
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));

      // Listen to scan results
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return; // Ensure the widget is still in the tree
        setState(() {
          for (var result in results) {
            if (result.advertisementData.serviceUuids.contains(desiredUUID)) {
              if (!devices.any((device) => device['id'] == result.device.id.id)) {
                devices.add({
                  'name': result.device.name.isNotEmpty ? result.device.name : "Unknown",
                  'id': result.device.id.id,
                  'device': result.device,
                });
              }
            }
          }
        });
      });

      // No need to manually handle isScanning; it's managed by the isScanning stream
    } catch (e) {
      // Handle any errors during scanning
      _showErrorDialog('Errore durante la scansione.');
    }
  }

  void toggleScan() {
    FlutterBluePlus.isScanning.first.then((scanning) {
      if (scanning) {
        FlutterBluePlus.stopScan();
        // The isScanning stream will automatically update the UI
      } else {
        scanDevices();
      }
    });
  }

Future<void> connectToDevice(BuildContext context, BluetoothDevice device) async {
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpinKitRipple(
              color: Colors.white,
              size: 50.0,
            ),
            const SizedBox(height: 10),
            const Text(
              'Connessione...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    },
  );

  try {
    // Connect to device
    await device.connect();
    connectedDevice = device;

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          ledCharacteristic = characteristic;

          // Dismiss loading dialog
          Navigator.of(context).pop();

          _showLedControlModal();
          return;
        }
      }
    }

    // If no writable characteristic is found
    Navigator.of(context).pop(); // Dismiss loading dialog
    _showErrorDialog('Caratteristica scrivibile non trovata.');
  } catch (e) {
    // Handle connection error
    Navigator.of(context).pop(); // Dismiss loading dialog
    _showErrorDialog('Errore durante la connessione.');
  }
}

  void _showLedControlModal() {
    Future<void> _pickTime() async {
      TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: selectedTime,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), // Enforce 24-hour format
            child: Theme(
              data: Theme.of(context).copyWith(
                timePickerTheme: TimePickerThemeData(
                  backgroundColor: Theme.of(context).splashColor, // Use splashColor for background
                  hourMinuteShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.black, width: 2), // Border for hour/minute fields
                  ),
                  hourMinuteTextStyle: const TextStyle(
                    color: Colors.white, // White text for readability
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                      states.contains(MaterialState.selected)
                          ? Theme.of(context).splashColor
                          : Colors.black), // SplashColor when selected, Black otherwise
                  hourMinuteTextColor: MaterialStateColor.resolveWith((states) =>
                      states.contains(MaterialState.selected)
                          ? Colors.white
                          : Colors.white), // White text for both states
                  dialBackgroundColor: Colors.black,
                  dialHandColor: Theme.of(context).splashColor,
                  dialTextColor: Colors.white,
                  entryModeIconColor: Colors.white, // White keyboard icon
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white, // Default text color for buttons
                  ),
                ),
                buttonTheme: ButtonThemeData(
                  textTheme: ButtonTextTheme.accent, // Use custom accent for Cancel
                ),
              ),
              child: Builder(
                builder: (context) {
                  return child!;
                },
              ),
            ),
          );
        },
      );
      if (time != null) {
        setState(() {
          selectedTime = time; // Update the selected time
        });
      }
    }

    Future<bool> _checkPermissionsBeforeNavigation() async {
      if (Platform.isAndroid) {
        bool locationGranted = await Permission.location.isGranted;
        bool scanGranted = await Permission.bluetoothScan.isGranted;
        bool connectGranted = await Permission.bluetoothConnect.isGranted;

        if (!locationGranted) {
          locationGranted = (await Permission.location.request()) == PermissionStatus.granted;
        }
        if (!scanGranted) {
          scanGranted = (await Permission.bluetoothScan.request()) == PermissionStatus.granted;
        }
        if (!connectGranted) {
          connectGranted = (await Permission.bluetoothConnect.request()) == PermissionStatus.granted;
        }

        return locationGranted && scanGranted && connectGranted;
      }

      // For iOS, assume permissions are handled in Info.plist
      return true;
    }

    void _sendTimeToESP() async {
      if (ledCharacteristic != null) {
        try {
          String timeString =
              "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";
          await ledCharacteristic!.write(Uint8List.fromList(timeString.codeUnits));

          // Close the modal dialog after sending time
          Navigator.of(context).pop();
        showNotification(context, "Tempo sincronizzato con successo!", true);

          // Show a success snackbar
         

          // Wait for the snackbar to display before navigating
         
            bool permissionsGranted = await _checkPermissionsBeforeNavigation();
            if (permissionsGranted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FiglioLogScreen()),
              );
            } else {
              _showErrorDialog('Permessi necessari non concessi.');
            }
          
        } catch (e) {
          // Handle write error
          _showErrorDialog('Errore durante la sincronizzazione.');
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Theme.of(context).splashColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ragno',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        await _pickTime();
                        setStateDialog(() {}); // Refresh the dialog to reflect the new time
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(fontSize: 16, color: Colors.black),
                            ),
                            const Icon(Icons.access_time, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _sendTimeToESP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sincronizza'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    return GestureDetector(
onTap: () => connectToDevice(context, device['device']),
      child: Card(
        elevation: 4,
        color: Theme.of(context).splashColor,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                device['name'],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                device['id'],
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
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
        title: const Text('LED Control', style: TextStyle(color: Colors.white)),
        actions: [
          // Scan/Refresh button with dynamic icon
          StreamBuilder<bool>(
            stream: FlutterBluePlus.isScanning,
            initialData: false,
            builder: (context, snapshot) {
              bool scanning = snapshot.data ?? false;
              return IconButton(
                icon: scanning
                    ? SpinKitRipple(
                        color: Colors.white,
                        size: 24.0,
                      )
                    : Icon(Icons.refresh, color: Colors.white),
                onPressed: toggleScan,
                tooltip: scanning ? 'Stop Scan' : 'Refresh Scan',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: StreamBuilder<bool>(
                      stream: FlutterBluePlus.isScanning,
                      initialData: false,
                      builder: (context, snapshot) {
                        bool scanning = snapshot.data ?? false;
                        if (scanning) {
                          return SpinKitRipple(
                            color: Colors.white,
                            size: 24.0,
                          );
                        } else {
                          return const Text(
                            "Nessun ragno trovato.",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          );
                        }
                      },
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      return _buildDeviceCard(devices[index]);
                    },
                  ),
          ),
        ],
      ),
      // Removed FloatingActionButton as scan controls are now in the AppBar
      // If you need the FAB for another function, you can add it back here
    );
  }
}
