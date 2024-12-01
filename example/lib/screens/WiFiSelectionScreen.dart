import 'package:flutter/material.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:kbeacon_plugin_example/utils/notification_helper.dart';

class WifiNetwork {
  final String ssid;
  final int rssi;

  WifiNetwork({required this.ssid, required this.rssi});
}

class WifiSelectionScreen extends StatefulWidget {
  final String deviceName;

  const WifiSelectionScreen({Key? key, required this.deviceName}) : super(key: key);

  @override
  State<WifiSelectionScreen> createState() => _WifiSelectionScreenState();
}

class _WifiSelectionScreenState extends State<WifiSelectionScreen> {
  final _flutterEspBleProvPlugin = FlutterEspBleProv();
  List<WifiNetwork> networks = [];
  String feedbackMessage = '';
  String selectedSsid = '';
  bool isProvisioning = false;

  @override
  void initState() {
    super.initState();
    scanWifiNetworks();
  }

  Future<void> scanWifiNetworks() async {
    try {
      final scannedNetworks = await _flutterEspBleProvPlugin.scanWifiNetworks(widget.deviceName, 'abcd1234');
      setState(() {
        networks = scannedNetworks.map((network) {
          return WifiNetwork(
            ssid: network.ssid,
            rssi: network.rssi,
          );
        }).toList();
      });
    } catch (e) {
      // Error handling can be added here
    }
  }

  int _getSignalLevel(int rssi) {
    if (rssi > -50) {
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

  Widget _buildSignalBar(int rssi) {
    int level = _getSignalLevel(rssi);
    Color signalColor = _getSignalColor(level);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        bool isActive = index < level;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 4,
          height: isActive ? 16 : 8,
          decoration: BoxDecoration(
            color: isActive ? signalColor : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: signalColor.withOpacity(0.6),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildWifiCard(WifiNetwork network) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSsid = network.ssid;
        });
        _showPasswordModal(network.ssid);
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
                  network.ssid,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                _buildSignalBar(network.rssi),
              ],
            ),
          ),
        ),
      ),
    );
  }
Future<void> _showPasswordModal(String networkName) async {
  final passphraseController = TextEditingController();
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
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
                'Enter Wi-Fi Password',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                "Network: $networkName",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passphraseController,
                decoration: InputDecoration(
                  hintText: 'Enter password...',
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: Colors.white),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    isProvisioning = true;
                  });

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
                              'Provisioning...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  );

                  try {
                    final success = await _flutterEspBleProvPlugin.provisionWifi(
                      widget.deviceName,
                      'abcd1234',
                      networkName,
                      passphraseController.text,
                    );

                    final message = success ?? false
                        ? 'Wi-Fi Provisioned Successfully'
                        : 'Failed to Provision Wi-Fi';
                    final color = success ?? false ? Colors.green : Colors.red;

                    showNotification(context, message, success ?? false);

                    // Close loading dialog
                    Navigator.pop(context); // Pop the loading dialog

                    // Close WifiSelectionScreen only if provisioning is successful
                    if (success ?? false) {
                      Navigator.pop(context); // This pops the WifiSelectionScreen
                    }
                  } catch (e) {
                    showNotification(context, 'Error provisioning Wi-Fi: $e', false);

                    // Close loading dialog
                    Navigator.pop(context); // Pop the loading dialog
                  } finally {
                    setState(() {
                      isProvisioning = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: isProvisioning
                    ? SpinKitCircle(color: Colors.white, size: 30.0)
                    : const Text('Provision'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the modal
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
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Select Wi-Fi Network'),
        actions: [
          IconButton(
            icon: SpinKitRipple(
              color: Colors.white,
              size: 24.0,
            ),
            onPressed: scanWifiNetworks,
            tooltip: 'Refresh Scan',
          ),
        ],
      ),
      body: isProvisioning
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: networks.isEmpty
                      ? Center(
                          child: Text(
                            'No Wi-Fi networks found',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 4.0,
                          ),
                          itemCount: networks.length,
                          itemBuilder: (context, index) {
                            return _buildWifiCard(networks[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
