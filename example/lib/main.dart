import 'package:flutter/material.dart';
import './screens/HomeScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io'; // Import for Platform
import 'package:flutter_bloc/flutter_bloc.dart'; // Add the flutter_bloc package
import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart'; // Import the bloc

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures Flutter bindings are initialized

  if (Platform.isAndroid) {
    // Requesting multiple permissions sequentially
    await Permission.locationWhenInUse.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.camera.request();
    await Permission.notification.request();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Provide EspProvisioningBloc here so it is available throughout the app
      create: (_) => EspProvisioningBloc(),
      child: MaterialApp(
        title: 'AG Chrono',
        theme: ThemeData(
          primaryColor: const Color.fromARGB(255, 0, 0, 0),
          splashColor: const Color.fromARGB(255, 30, 30, 30),
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.white, // Change background to white
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
