import 'package:flutter/material.dart';
import 'package:kbeacon_plugin/kbeacon_plugin.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBeacon Plugin Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, Map<String, dynamic>> _beaconMap = {};  // Use a map to store beacons by MAC address with their details
  List<String> _beacons = [];
  String _error = '';
  String _bleState = '';
  bool _isScanning = false; // Add a variable to track scanning state
  final _kbeaconPlugin = KbeaconPlugin();
  final Duration beaconTimeout = Duration(seconds: 10);  // Timeout after 10 seconds of inactivity

  @override
  void initState() {
    super.initState();
    _startBeaconCleanup();  // Start the cleanup timer
  }

  void _startScanning() async {
    setState(() {
      _isScanning = true;  // Set scanning state to true
    });
    await _kbeaconPlugin.startScan();
    _kbeaconPlugin.listenToScanResults(
      (List<String> beacons) {
        setState(() {
          _updateBeacons(beacons);
        });
      },
      (String errorMessage) {
        setState(() {
          _error = errorMessage;
          _isScanning = false;  // Stop scanning if an error occurs
        });
      },
      (String bleState) {
        setState(() {
          _bleState = bleState;
        });
      }
    );
  }

  void _updateBeacons(List<String> beacons) {
    final now = DateTime.now();
    for (var beacon in beacons) {
      // Extract the MAC address and any additional information
      final beaconParts = beacon.split(", ");
      final macAddress = beaconParts[0].split(": ")[1]; // Assuming "MAC: <address>" format

      // If the beacon is already in the map, update its details
      _beaconMap[macAddress] = {
        "info": beacon,  // Store the whole beacon info as you receive it
        "lastSeen": now  // Update the last seen timestamp
      };
    }

    // Update the visible beacon list
    _beacons = _beaconMap.values.map((beaconData) => beaconData["info"] as String).toList();
  }

  void _startBeaconCleanup() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        // Remove devices that haven't been seen within the timeout duration
        _beaconMap.removeWhere((macAddress, beaconData) => now.difference(beaconData["lastSeen"] as DateTime) > beaconTimeout);
        // Update the visible beacon list
        _beacons = _beaconMap.values.map((beaconData) => beaconData["info"] as String).toList();
      });
    });
  }

  void _connectAndChangeName(String macAddress) async {
    try {
      await _kbeaconPlugin.connectToDevice(macAddress, "Matteo11!");
      _showNameChangeDialog(macAddress);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _showNameChangeDialog(String macAddress) {
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Change Device Name"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "New Name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _changeDeviceName(macAddress, nameController.text);
                Navigator.of(context).pop();
              },
              child: const Text("Change"),
            ),
          ],
        );
      },
    );
  }

  void _changeDeviceName(String macAddress, String newName) async {
    try {
      await _kbeaconPlugin.changeDeviceName(newName);
      setState(() {
        _error = "Device name changed to $newName";
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KBeacon Scan Results'),
      ),
      body: Column(
        children: [
          if (_bleState.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Bluetooth State: $_bleState', style: const TextStyle(color: Colors.blue)),
            ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: _isScanning ? null : _startScanning,  // Disable button if scanning is in progress
            child: Text(_isScanning ? 'Scanning...' : 'Start Scan'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _beacons.length,
              itemBuilder: (context, index) {
                String beaconInfo = _beacons[index];
                return ListTile(
                  title: Text(beaconInfo),
                  onTap: () {
                    String macAddress = beaconInfo.split(",")[0].replaceFirst("MAC: ", "");
                    _connectAndChangeName(macAddress);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
