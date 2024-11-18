import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './BeaconSelectionScreen.dart'; // Import the BeaconSelectionScreen

class BeaconScreen extends StatefulWidget {
  const BeaconScreen({super.key});

  @override
  State<BeaconScreen> createState() => _BeaconScreenState();
}

class _BeaconScreenState extends State<BeaconScreen> {
  bool _isLoggedIn = false;
  String? _role;

  @override
  void initState() {
    super.initState();
    _fetchLoginStatus();
  }

  // Fetch login status and role from SharedPreferences
  Future<void> _fetchLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    setState(() {
      _isLoggedIn = token != null && role != null;
      _role = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor, // Set background color to primary color
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Replace the Bluetooth icon with the WebP image
              Image.asset(
                'assets/images/beacon_image.png', // Path to the WebP image
                height: 100, // Adjust the height based on your design
                fit: BoxFit.contain, // Ensure the image fits well within its bounds
              ),
              const SizedBox(height: 30),
              Text(
                'Configura Beacon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Title in bold and white
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Modifica l\'assegnazione dei beacon.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70, // Descriptive text in lighter white
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BeaconSelectionScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Theme.of(context).splashColor, // Button color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0), // Rounded button shape
                  ),
                ),
                child: const Text(
                  'Inizializza configurazione',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
