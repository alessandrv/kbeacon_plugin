import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_event.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
import 'WiFiSelectionScreen.dart';

class DeviceSelectionScreen extends StatefulWidget {
  @override
  _DeviceSelectionScreenState createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  final prefixController = TextEditingController(text: 'PROV_');
  String feedbackMessage = '';

  @override
  void initState() {
    super.initState();
    // Start scanning for BLE devices when the screen is initialized
    context.read<EspProvisioningBloc>().add(EspProvisioningEventStart(prefixController.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleziona un Dispositivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () {
              // Start scanning when the button is pressed
              context.read<EspProvisioningBloc>().add(EspProvisioningEventStart(prefixController.text));
              setState(() {
                feedbackMessage = 'Scanning BLE devices...';
              });
            },
          ),
        ],
      ),
      body: BlocBuilder<EspProvisioningBloc, EspProvisioningState>(
        builder: (context, state) {
          if (state.bluetoothDevices.isEmpty) {
            return Center(
              child: Text(feedbackMessage.isEmpty ? 'Avvio della scansione BLE...' : feedbackMessage),
            );
          }

          return ListView.builder(
            itemCount: state.bluetoothDevices.length,
            itemBuilder: (context, index) {
              final device = state.bluetoothDevices[index];
              return ListTile(
                title: Text(device),
                onTap: () {
                  // When a device is tapped, navigate to WiFiSelectionScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WifiSelectionScreen(deviceName: device),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
