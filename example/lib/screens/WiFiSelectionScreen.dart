import 'package:flutter/material.dart';
import 'dart:async';
import 'package:kbeacon_plugin/kbeacon_plugin.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class WifiSelectionScreen extends StatefulWidget {
  final String deviceName;
  const WifiSelectionScreen({super.key, required this.deviceName});

  @override
  State<WifiSelectionScreen> createState() => _WifiSelectionScreenState();
}
class _WifiSelectionScreenState extends State<WifiSelectionScreen> {
  final _flutterEspBleProvPlugin = KbeaconPlugin();
  List<String> networks = [];
  String feedbackMessage = '';
  bool isConnecting = false;
  bool isProvisioning = false;
  bool _hasCompletedScan = false;

  @override
  void initState() {
    super.initState();
    _scanWifiNetworks();
  }

  Future<void> _scanWifiNetworks() async {
    setState(() {
      networks.clear();
      isConnecting = true;
      feedbackMessage = '';
      _hasCompletedScan = false;
    });

    try {
      final proofOfPossession = 'abcd1234';
      final scannedNetworks = await _flutterEspBleProvPlugin.scanWifiNetworks(widget.deviceName, proofOfPossession);
      _completeScan(scannedNetworks);
    } catch (e) {
      _handleScanError('Error scanning networks: $e');
    }
  }

  void _completeScan(List<String> scannedNetworks) {
    if (!_hasCompletedScan) {
      _hasCompletedScan = true;
      setState(() {
        networks = scannedNetworks;
        isConnecting = false;
      });
    }
  }

  void _handleScanError(String errorMessage) {
    if (!_hasCompletedScan) {
      _hasCompletedScan = true;
      setState(() {
        isConnecting = false;
        feedbackMessage = errorMessage;
      });
    }
  }

  Future<void> _provisionWifi(String ssid, String passphrase) async {
    final proofOfPossession = 'abcd1234';
    setState(() {
      isProvisioning = true; // Set provisioning state
    });

    try {
      await _flutterEspBleProvPlugin.provisionWifi(widget.deviceName, proofOfPossession, ssid, passphrase);
      setState(() {
        feedbackMessage = 'Successfully provisioned WiFi: $ssid';
        isProvisioning = false; // Reset the state
      });
      _navigateBackToHome(); // Go back to the home screen
    } catch (e) {
      setState(() {
        feedbackMessage = 'Failed to provision WiFi: $ssid. Error: $e';
        isProvisioning = false; // Reset the state
      });
    }
  }

  void _connectToWifi(String ssid) {
    String passphrase = '';
    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismiss by clicking outside
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Connect to $ssid',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Enter WiFi password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      onChanged: (value) {
                        passphrase = value;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close the dialog
                          },
                          child: const Text(
                            'Cancella',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                    
                        ElevatedButton(
                     
                          onPressed: () async {
                            setState(() {
                              isProvisioning = true; // Show loading spinner for provisioning
                            });
                            await _provisionWifi(ssid, passphrase);
                            Navigator.pop(context); // Close the dialog when connected
                          },
                          
                          child: const Text('Connetti'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, // Text color
                    backgroundColor: Theme.of(context).primaryColor, // Button color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0), // Rounded corners
                    ),
                  ),
                
                        ),
                      ],
                    ),
                    if (isProvisioning)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SpinKitRipple(color: Colors.purple), // Indicate provisioning
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

  void _navigateBackToHome() {
    Navigator.popUntil(context, (route) => route.isFirst); // Pop back to the first (Home) screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WiFi Connected Successfully')),
    );
  }

  @override
  void dispose() {
    
    // Clean up any ongoing WiFi or BLE operations when exiting the screen
    super.dispose();
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Select WiFi Network'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _scanWifiNetworks, // Trigger a new scan when pressed
        ),
      ],
    ),
    body: isConnecting
        ? Center(
            child: SpinKitRipple(color: Theme.of(context).primaryColor), // Show spinner while scanning
          )
        : networks.isEmpty
            ? const Center(child: Text('No networks found.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: networks.length,
                itemBuilder: (context, index) {
                  return _buildWifiListItem(networks[index]);
                },
              ),
    bottomSheet: feedbackMessage.isNotEmpty
        ? Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(12.0),
            child: Text(
              feedbackMessage,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green.shade600),
            ),
          )
        : const SizedBox.shrink(),
  );
}

Widget _buildWifiListItem(String network) {
  return ListTile(
    leading: Icon(Icons.wifi, color: Theme.of(context).primaryColor),
    title: Text(
      network,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
    subtitle: Row(
      children: const [
        Icon(Icons.signal_wifi_4_bar, size: 14, color: Colors.grey),
        SizedBox(width: 4),
        Icon(Icons.lock, size: 14, color: Colors.grey),
      ],
    ),
    trailing: const Icon(Icons.arrow_forward),
    onTap: () => _connectToWifi(network),
  );
}
}