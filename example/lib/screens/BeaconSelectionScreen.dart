// beacon_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:kbeacon_plugin/kbeacon_plugin.dart';
import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart'; // Ensure the spinkit package is added
import 'package:flutter/services.dart'; // For input formatters
import 'package:numberpicker/numberpicker.dart'; // Import the NumberPicker package
import 'package:kbeacon_plugin_example/utils/notification_helper.dart'; // Adjust the path to your project's structure
import 'beacon.dart'; // Import the Beacon model

class BeaconSelectionScreen extends StatefulWidget {
  const BeaconSelectionScreen({Key? key}) : super(key: key);

  @override
  _BeaconSelectionScreenState createState() => _BeaconSelectionScreenState();
}

class _BeaconSelectionScreenState extends State<BeaconSelectionScreen> {
  Map<String, Beacon> _beaconMap = {}; // Updated to use Beacon objects
  List<String> _beacons = [];
  String _error = '';
  String _message = '';
  String _bleState = '';
  final _kbeaconPlugin = KbeaconPlugin();
  final Duration beaconTimeout = Duration(seconds: 10);

  // Add MobileScannerController
  final MobileScannerController scannerController = MobileScannerController();

  StreamSubscription<List<Beacon>>? _scanSubscription;
  StreamSubscription<String>? _bleStateSubscription;

  @override
  void initState() {
    super.initState();
    _startScanning();
    _startBeaconCleanup();
  }

  void _startScanning() async {
    try {
      await _kbeaconPlugin.startScan();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      return;
    }

    // Subscribe to scan results stream
    _scanSubscription = _kbeaconPlugin.scanResultsStream.listen((beacons) {
      setState(() {
        _updateBeacons(beacons);
      });
    }, onError: (error) {
      setState(() {
        _error = 'Scan failed: $error';
      });
    });

    // Subscribe to BLE state changes
    _bleStateSubscription = _kbeaconPlugin.bleStateStream.listen((state) {
      setState(() {
        _bleState = state;
      });
    });
  }

  void _updateBeacons(List<Beacon> beacons) {
    final now = DateTime.now();
    for (var beacon in beacons) {
      _beaconMap[beacon.mac] = beacon.copyWith(lastSeen: now); // Update lastSeen
    }

    // Remove old beacons
    _beaconMap.removeWhere((mac, beacon) =>
        now.difference(beacon.lastSeen) > beaconTimeout);

    // Update the visible beacon list
    _beacons = _beaconMap.keys.toList();
  }

  void _startBeaconCleanup() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _beaconMap.removeWhere((macAddress, beacon) =>
            now.difference(beacon.lastSeen) > beaconTimeout);
        _beacons = _beaconMap.keys.toList();
      });
    });
  }

  void _connectAndChangeName(String macAddress) async {
    int maxAttempts = 3; // Maximum number of retry attempts
    int attempt = 0; // Start with attempt 0
    bool connected = false; // Track if the connection was successful

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

    while (attempt < maxAttempts && !connected) {
      attempt++;

      try {
        await _kbeaconPlugin.connectToDevice(macAddress, "Matteo11!");
        connected = true; // Mark as successful connection
      } catch (e) {
        if (attempt >= maxAttempts) {
          // After max attempts, fail and show error notification
          Navigator.of(context).pop();
          showNotification(context, "Failed to connect after $maxAttempts attempts", false);
          return;
        }
        // Optionally, add a delay before retrying
        await Future.delayed(Duration(seconds: 2));
      }
    }

    if (connected) {
      Navigator.of(context).pop();
      _showNameChangeDialog(macAddress); // Proceed to name change if connected
    }
  }

  void _showNameChangeDialog(String macAddress) {
    final beacon = _beaconMap[macAddress];
    final name = beacon?.name ?? "Unknown";

    // Extract the numeric part from the name
    String displayName = name.contains('_')
        ? name.split('_').last
        : name;
    displayName = displayName.replaceFirst(RegExp(r'^0+'), '');
    if (displayName.isEmpty) {
      displayName = "0";
    }

    // Variable to hold the number input
    int currentNumber = int.tryParse(displayName) ?? 0; // Default value 0

    // Controller for manual input
    TextEditingController manualInputController = TextEditingController(text: currentNumber.toString());

    // Whether to show the manual input field (initially false)
    bool showTextField = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            _disconnectDevice();
            return true;
          },
          child: StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                backgroundColor: Theme.of(context).splashColor, // Use splash color for the background
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // Make the dialog rounded
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Ensures the dialog takes up minimum space
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Card with Image and Details
                      Card(
                        color: Colors.white, // Card background color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Beacon Image
                              Image.asset(
                                'assets/images/beacon_image.png', // Your image asset
                                width: 50, // Adjust the width based on your design
                                height: 50, // Adjust the height based on your design
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 16),
                              // ID and MAC address
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID: $displayName',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black, // Black text for the ID
                                    ),
                                  ),
                                  Text(
                                    'MAC: $macAddress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87, // Slightly dimmed black for the MAC address
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Stack to show either NumberPicker or TextField
                      Stack(
                        alignment: Alignment.center, // Center the NumberPicker and the TextField
                        children: [
                          // Show NumberPicker only if TextField is not visible
                          if (!showTextField)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  showTextField = true; // Show the TextField when tapped
                                });
                              },
                              child: NumberPicker(
                                value: currentNumber,
                                axis: Axis.horizontal,
                                minValue: 0,
                                maxValue: 999, // Limiting to 3 digits
                                onChanged: (value) {
                                  setState(() {
                                    currentNumber = value;
                                    manualInputController.text = currentNumber.toString();
                                  });
                                },
                                textStyle: TextStyle(color: Colors.white70),
                                selectedTextStyle: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // Show TextField if the user taps the NumberPicker
                          if (showTextField)
                            Positioned(
                              child: Container(
                                width: 100,
                                child: TextField(
                                  controller: manualInputController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  autofocus: true, // Automatically focus the input field
                                  style: TextStyle(fontSize: 24, color: Colors.white),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) {
                                    // Trigger the set action when user submits via keyboard
                                    _setNameChange(setState, macAddress, manualInputController);
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Cancel button
                          TextButton(
                            onPressed: () {
                              _disconnectDevice();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              "Cancella",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Set button
                          ElevatedButton(
                            onPressed: () {
                              if (showTextField) {
                                // We are in manual input mode
                                String input = manualInputController.text.trim();
                                int? newValue = int.tryParse(input);
                                if (newValue == null || newValue < 0 || newValue > 999) {
                                  showNotification(context, 'Valore non valido. Inserisci un numero tra 0 e 999.', false);
                                  return;
                                }
                                setState(() {
                                  currentNumber = newValue;
                                  showTextField = false; // Close the TextField
                                });
                                _changeDeviceName(macAddress, currentNumber.toString());
                              } else {
                                // Not in manual input mode, proceed to change the device name
                                _changeDeviceName(macAddress, currentNumber.toString());
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor, // Use primary color for the button
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                            ),
                            child: Text(showTextField ? 'Imposta' : 'Cambia'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ).then((_) {
      _disconnectDevice();
    });
  }

  // Helper method to handle name change from TextField submission
  void _setNameChange(StateSetter setState, String macAddress, TextEditingController controller) {
    String input = controller.text.trim();
    int? newValue = int.tryParse(input);
    if (newValue == null || newValue < 0 || newValue > 999) {
      showNotification(context, 'Valore non valido. Inserisci un numero tra 0 e 999.', false);
      return;
    }
    setState(() {
      // Update currentNumber and hide TextField
      // (Assuming currentNumber is accessible here; if not, restructure accordingly)
    });
    _changeDeviceName(macAddress, newValue.toString());
  }

  void _changeDeviceName(String macAddress, String userInput) async {
    String formattedNumber = userInput.padLeft(3, '0'); // Ensures at least 3 digits
    String formattedName = 'macchina_$formattedNumber';

    try {
      await _kbeaconPlugin.changeDeviceName(formattedName);

      // Show success notification
      showNotification(context, "Dispositivo impostato con ID: $userInput", true);
    } catch (e) {
      // Show error notification
      showNotification(context, "Errore durante l'aggiornamento dell'ID.", false);
    } finally {
      _disconnectDevice(); // Ensure the device is disconnected
    }
  }

  void _disconnectDevice() async {
    try {
      await _kbeaconPlugin.disconnectDevice();
      print("disconnecting device");
    } catch (e) {
      print("Error disconnecting device: $e");
    }
  }

  // Helper function to determine signal level based on RSSI
  int _getSignalLevel(int rssi) {
    if (rssi > -45) {
      return 5;
    } else if (rssi > -60) {
      return 4;
    } else if (rssi > -70) {
      return 3;
    } else if (rssi > -80) {
      return 2;
    } else {
      return 1;
    }
  }

  Color _getSignalColor(int level) {
    switch (level) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.yellow;
      case 2:
        return Colors.orange;
      case 1:
      default:
        return Colors.red;
    }
  }

  // Widget to display signal bars
  Widget _buildSignalBar(int rssi) {
    int level = _getSignalLevel(rssi);
    Color signalColor = _getSignalColor(level);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        bool isActive = index < level;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5), // Adjusted margin
          width: 4, // Smaller width
          height: isActive ? 16 : 8, // Smaller height
          decoration: BoxDecoration(
            color: isActive ? signalColor : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: signalColor.withOpacity(0.6),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1), // smaller shadow offset
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBeaconCard(String macAddress) {
    final beacon = _beaconMap[macAddress];
    if (beacon == null) {
      return SizedBox.shrink();
    }

    final name = beacon.name;
    final rssi = beacon.rssi;

    String displayName;
    if (name.startsWith('macchina_')) {
      // Extract the last 3 characters of the name after "macchina_"
      displayName = name.substring('macchina_'.length);
      displayName = displayName.replaceFirst(RegExp(r'^0+'), ''); // Remove leading zeros
      if (displayName.isEmpty) {
        displayName = "0";
      }
    } else {
      // Name does not start with "macchina_"
      displayName = "?";
    }

    return GestureDetector(
      onTap: () => _connectAndChangeName(macAddress),
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
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Add the WebP image
                Image.asset(
                  'assets/images/beacon_image.png', // Replace with your image path
                  width: double.infinity, // Full width of the card minus padding
                  height: 20, // Adjust the height as needed
                  fit: BoxFit.contain, // Ensures the image fits properly
                ),
                const SizedBox(height: 8), // Spacing between image and signal bars
                // Display the signal bar
                _buildSignalBar(rssi),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error.isNotEmpty) {
      return Center(
        child: Text(
          'Error: $_error',
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    } else if (_message.isNotEmpty) {
      return Center(
        child: Text(
          _message,
          style: const TextStyle(color: Colors.green, fontSize: 16),
        ),
      );
    } else if (_beacons.isEmpty) {
      return Center(
        child: Text(
          'No beacons found',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    } else {
      // Change ListView.builder to GridView.builder
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // Three columns
          crossAxisSpacing: 8, // Spacing between columns
          mainAxisSpacing: 8, // Spacing between rows
          childAspectRatio: 0.8, // Square cards
        ),
        itemCount: _beacons.length,
        itemBuilder: (context, index) {
          String macAddress = _beacons[index];
          return _buildBeaconCard(macAddress);
        },
      );
    }
  }

  void _refreshScan() {
    setState(() {
      _beaconMap.clear();
      _beacons.clear();
      _error = '';
      _message = '';
    });
    _startScanning();
  }

  // QR Scanner Methods
  void _startQrScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).primaryColor, // AppBar color
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Scannerizza QR'),
          ),
          body: Stack(
            children: [
              MobileScanner(
                controller: scannerController,
                onDetect: _onQRViewScanned,
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  child: CustomPaint(
                    painter: CornerPainter1(inset: 20.0), // Adjust the inset value here
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onQRViewScanned(BarcodeCapture barcodeCapture) {
    final barcode = barcodeCapture.barcodes.first;
    if (barcode.rawValue != null) {
      final qrData = barcode.rawValue!;
      scannerController.stop();
      Navigator.pop(context);
      _processQrData(qrData);
    }
  }

  void _processQrData(String qrData) {
    // Example QR data: "MAC:BC572904806A,SERIAL:418467;"
    final data = qrData.split(',');
    String? macAddress;

    for (var item in data) {
      if (item.startsWith('MAC:')) {
        macAddress = item.replaceFirst('MAC:', '').trim();
      }
    }

    if (macAddress != null) {
      // Add colons to the MAC address if needed
      macAddress = _formatMacAddress(macAddress);
      _connectAndChangeName(macAddress);
    } else {
      setState(() {
        _error = 'Invalid QR code data: MAC address not found';
      });
    }
  }

  String _formatMacAddress(String mac) {
    // Format MAC address to standard notation (e.g., "BC:57:29:04:80:6A")
    if (mac.length == 12) {
      return mac.replaceAllMapped(RegExp(r'.{2}'), (match) => '${match.group(0)}:').substring(0, 17);
    }
    return mac; // Return as is if not 12 characters
  }

  @override
  void dispose() {
    scannerController.dispose();
    _disconnectDevice();
    _scanSubscription?.cancel();
    _bleStateSubscription?.cancel();
    super.dispose();
    // Dispose any resources like subscriptions or timers if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Beacon vicini'),
        actions: [
          IconButton(
            icon: SpinKitRipple(
              color: Colors.white,
              size: 24.0,
            ),
            onPressed: _refreshScan, // Allow refreshing scan when pressed
            tooltip: 'Refresh Scan',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_bleState.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blue.shade100,
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Bluetooth State: $_bleState',
                style: const TextStyle(color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startQrScan,
        child: Icon(
          Icons.qr_code_scanner,
          color: Colors.white,
        ),
        tooltip: 'Scan QR Code',
        backgroundColor: Theme.of(context).splashColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// Custom painter for corner borders
class CornerPainter1 extends CustomPainter {
  final double inset;

  CornerPainter1({this.inset = 20.0}); // Adjust the inset value as needed

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final radius = 16.0;
    final length = 40.0;

    // Adjusted positions using inset
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    // Draw top-left corner
    canvas.drawLine(Offset(left, top + radius), Offset(left, top + length), paint);
    canvas.drawLine(Offset(left + radius, top), Offset(left + length, top), paint);

    // Draw top-right corner
    canvas.drawLine(Offset(right - radius, top), Offset(right - length, top), paint);
    canvas.drawLine(Offset(right, top + radius), Offset(right, top + length), paint);

    // Draw bottom-left corner
    canvas.drawLine(Offset(left, bottom - radius), Offset(left, bottom - length), paint);
    canvas.drawLine(Offset(left + radius, bottom), Offset(left + length, bottom), paint);

    // Draw bottom-right corner
    canvas.drawLine(Offset(right - radius, bottom), Offset(right - length, bottom), paint);
    canvas.drawLine(Offset(right, bottom - radius), Offset(right, bottom - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
