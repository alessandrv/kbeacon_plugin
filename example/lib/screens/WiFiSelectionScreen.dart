import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_event.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class WifiSelectionScreen extends StatefulWidget {
  final String deviceName;

  const WifiSelectionScreen({super.key, required this.deviceName});

  @override
  State<WifiSelectionScreen> createState() => _WifiSelectionScreenState();
}

class _WifiSelectionScreenState extends State<WifiSelectionScreen> {
  final proofOfPossessionController = TextEditingController(text: 'abcd1234');
  final passphraseController = TextEditingController();
  String feedbackMessage = '';
  String selectedNetwork = '';
  bool isProvisioning = false; // To track provisioning status

  @override
  void initState() {
    super.initState();
    // Start scanning for WiFi networks when the screen is initialized
    context.read<EspProvisioningBloc>().add(EspProvisioningEventBleSelected(
      widget.deviceName,
      proofOfPossessionController.text,
    ));
  }

  void _showPasswordModal(String networkName) {
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
                  onPressed: () {
                    setState(() {
                      isProvisioning = true; // Start provisioning
                    });

                    context.read<EspProvisioningBloc>().add(EspProvisioningEventWifiSelected(
                      context.read<EspProvisioningBloc>().state.bluetoothDevice,
                      proofOfPossessionController.text,
                      networkName,
                      passphraseController.text,
                    ));
                    Navigator.of(context).pop(); // Close the modal
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Provision'),
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
        title: const Text('Select WiFi Network', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<EspProvisioningBloc>().add(EspProvisioningEventBleSelected(
                widget.deviceName,
                proofOfPossessionController.text,
              ));
              setState(() {
                feedbackMessage = 'Scanning WiFi networks...';
              });
            },
          ),
        ],
      ),
      body: isProvisioning
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SpinKitRipple(
                    color: Colors.white,
                    size: 50.0,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Connecting to Wi-Fi...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : BlocBuilder<EspProvisioningBloc, EspProvisioningState>(
              builder: (context, state) {
                if (state.wifiNetworks.isEmpty) {
                  return Center(
                    child: Text(feedbackMessage.isEmpty ? 'No WiFi networks found' : feedbackMessage, style: const TextStyle(color: Colors.white)),
                  );
                }

                return ListView.builder(
                  itemCount: state.wifiNetworks.length,
                  itemBuilder: (context, index) {
                    final network = state.wifiNetworks[index];

                    return Card(
                      color: Theme.of(context).splashColor, // Use the splash color as background
                      margin: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Icon(
                          Icons.wifi, // Wi-Fi icon
                          color: Colors.white,
                        ),
                        title: Text(
                          network,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        
                        onTap: () {
                          // Open the modal to enter the password
                          _showPasswordModal(network);
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
