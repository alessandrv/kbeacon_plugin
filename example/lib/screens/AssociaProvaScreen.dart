import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kbeacon_plugin_example/utils/notification_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class AssociaProvaScreen extends StatefulWidget {
  const AssociaProvaScreen({super.key});

  @override
  State<AssociaProvaScreen> createState() => _AssociaProvaScreenState();
}

class _AssociaProvaScreenState extends State<AssociaProvaScreen> {
  String? scanResult;
  String? manualInput;
  List<dynamic> manifestazioni = [];
  List<dynamic> prova = [];
  String? selectedManifestazione;
  String? selectedProva;
  bool isLoading = false; // For submission loading state
  bool isManifestazioneLoading = false; // For initial loading of manifestazioni
  bool isProvaLoading = false; // For loading the prova dropdown
  MobileScannerController scannerController = MobileScannerController();
  String? errorMessage; // Add this line

  @override
  void initState() {
    super.initState();
    fetchManifestazioni();
  }

  Future<void> fetchManifestazioni() async {
    setState(() {
      isManifestazioneLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final serverAddress = prefs.getString('serverAddress');
    try {
      final response = await http.get(
        Uri.parse('$serverAddress/manifestazioni'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          manifestazioni = jsonDecode(response.body);
        });
      } else {
        showError('Errore durante il caricamento. Controllare la connessione ad internet.');
      }
    } catch (e) {
      showError('Errore durante il caricamento. Controllare la connessione ad internet.');
    } finally {
      setState(() {
        isManifestazioneLoading = false;
      });
    }
  }

  Future<void> fetchProva(String manifestazioneId) async {
    setState(() {
      isProvaLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final serverAddress = prefs.getString('serverAddress');

    try {
      final response = await http.get(
        Uri.parse('$serverAddress/prova/$manifestazioneId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          prova = jsonDecode(response.body);
        });
      } else {
        showError('Failed to fetch prova');
      }
    } catch (e) {
      showError('Error fetching prova');
    } finally {
      setState(() {
        isProvaLoading = false;
      });
    }
  }

  Future<void> handleSubmit() async {
    final id = scanResult ?? manualInput;

    if (id == null || selectedManifestazione == null || selectedProva == null) {
      return showError('Please complete all fields');
    }

    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final serverAddress = prefs.getString('serverAddress');

    try {
      final response = await http.put(
        Uri.parse('$serverAddress/update-chrono'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'id': id,
          'id_manifestazione': selectedManifestazione,
          'id_prova': selectedProva,
        }),
      );

      if (response.statusCode == 200) {
        final message = jsonDecode(response.body)['message'];
        showSuccess(message);
      } else {
        showError('Failed to associate prova');
      }
    } catch (e) {
      showError('Error during association');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void onQRViewScanned(BarcodeCapture barcodeCapture) {
    final barcode = barcodeCapture.barcodes.first;
    if (barcode.rawValue != null) {
      setState(() {
        scanResult = barcode.rawValue!;
        manualInput = scanResult;
      });
      scannerController.stop();
      Navigator.pop(context);
    }
  }

  void showError(String message) {
    showNotification(context, message, false);
    setState(() {
      isLoading = false;
      errorMessage = message; // Set the error message
    });
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define colors
    final primaryColor = Theme.of(context).primaryColor;
    final invertedPrimaryColor = Colors.white;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'Associa Prova',
          style: TextStyle(color: invertedPrimaryColor),
        ),
        iconTheme: IconThemeData(color: invertedPrimaryColor),
      ),
      body: errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: TextStyle(color: invertedPrimaryColor, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            )
          : isManifestazioneLoading
              ? Center(
                  child: SpinKitRipple(
                    color: invertedPrimaryColor,
                    size: 100.0,
                  ),
                )
              : isLoading
                  ? Center(
                      child: SpinKitRipple(
                        color: invertedPrimaryColor,
                        size: 100.0,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        // Added to prevent overflow
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // Row with Device ID Input and Scan Button
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Device ID Input Field
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Enter Device ID', // Placeholder text
                                      filled: true,
                                      fillColor: Colors.white10, // Background color
                                      prefixIcon: Icon(
                                        Icons.devices,
                                        color: Colors.white, // Icon color
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none, // No border
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 20),
                                      hintStyle: TextStyle(
                                          color: Colors.white), // Hint text color
                                    ),
                                    controller:
                                        TextEditingController(text: manualInput),
                                    onChanged: (value) => manualInput = value,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white), // Text color
                                  ),
                                ),

                                const SizedBox(
                                    width: 8), // Space between input and button
                                // Scan Button (Icon only, no border)
                                IconButton(
                                  icon: Icon(Icons.qr_code_scanner,
                                      size: 28, color: invertedPrimaryColor),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Scaffold(
                                          appBar: AppBar(
                                            backgroundColor: primaryColor,
                                            title: Text(
                                              'Scan QR Code',
                                              style: TextStyle(
                                                  color: invertedPrimaryColor),
                                            ),
                                            iconTheme: IconThemeData(
                                                color: invertedPrimaryColor),
                                          ),
                                          body: Stack(
                                            children: [
                                              MobileScanner(
                                                controller: scannerController,
                                                onDetect: onQRViewScanned,
                                              ),
                                              Center(
                                                child: Container(
                                                  width: 250,
                                                  height: 250,
                                                  child: CustomPaint(
                                                    painter:
                                                        CornerPainter(), // Custom QR scanner overlay painter
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Manifestazione Dropdown with Loading Indicator
                            Stack(
                              children: [
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white10,
                                    prefixIcon: Icon(
                                      Icons.event,
                                      color: Colors.white,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(30), // Rounded corners
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 20),
                                  ),
                                  hint: Center(
                                    child: Text(
                                      'Select Manifestazione',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                  value: selectedManifestazione,
                                  items: manifestazioni.map((manifestazione) {
                                    return DropdownMenuItem<String>(
                                      value: manifestazione['id'].toString(),
                                      child: Text(manifestazione['nome'],
                                          style: const TextStyle(
                                              fontSize: 16, color: Colors.white)),
                                    );
                                  }).toList(),
                                  onChanged: isManifestazioneLoading
                                      ? null // Disable interaction while loading
                                      : (value) {
                                          setState(() {
                                            selectedManifestazione = value;
                                            prova = [];
                                            selectedProva = null;
                                          });
                                          fetchProva(value!);
                                        },
                                  dropdownColor: const Color.fromARGB(
                                      255, 26, 26, 26), // Dropdown background color
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.white), // Icon color
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                                if (isManifestazioneLoading)
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 12.0),
                                        child: SpinKitRipple(
                                            color: invertedPrimaryColor,
                                            size: 24),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Prova Dropdown with Loading Indicator
                            Stack(
                              children: [
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white10,
                                    prefixIcon: Icon(
                                      Icons.assignment,
                                      color: Colors.white,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(30), // Rounded corners
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 20),
                                  ),
                                  hint: Center(
                                    child: Text(
                                      'Select Prova',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                  value: selectedProva,
                                  items: prova.map((p) {
                                    return DropdownMenuItem<String>(
                                      value: p['id'].toString(),
                                      child: Text(p['nome'],
                                          style: const TextStyle(
                                              fontSize: 16, color: Colors.white)),
                                    );
                                  }).toList(),
                                  onChanged: isProvaLoading
                                      ? null // Disable interaction while loading
                                      : (value) {
                                          setState(() {
                                            selectedProva = value;
                                          });
                                        },
                                  dropdownColor: const Color.fromARGB(
                                      255, 26, 26, 26), // Dropdown background color
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: Colors.white), // Icon color
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                                if (isProvaLoading)
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 12.0),
                                        child: SpinKitRipple(
                                            color: invertedPrimaryColor,
                                            size: 24),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Submit button
                            ElevatedButton(
                              onPressed: handleSubmit,
                              child: const Text('Submit'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor:
                                    primaryColor, // Text color is primary color
                                backgroundColor:
                                    invertedPrimaryColor, // Button background is white
                                minimumSize:
                                    const Size.fromHeight(50), // Height of the button
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(30.0), // Rounded corners
                                ),
                                elevation: 5, // Elevation for shadow effect
                                side: BorderSide(
                                    color:
                                        primaryColor), // Optional: Add border with primary color
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

// Custom painter for corner borders
class CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white // Corner color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final radius = 16.0;
    final length = 40.0;

    // Draw top-left corner
    canvas.drawLine(Offset(0, radius), Offset(0, length), paint);
    canvas.drawLine(Offset(radius, 0), Offset(length, 0), paint);

    // Draw top-right corner
    canvas.drawLine(
        Offset(size.width - radius, 0), Offset(size.width - length, 0), paint);
    canvas.drawLine(
        Offset(size.width, radius), Offset(size.width, length), paint);

    // Draw bottom-left corner
    canvas.drawLine(Offset(0, size.height - radius),
        Offset(0, size.height - length), paint);
    canvas.drawLine(
        Offset(radius, size.height), Offset(length, size.height), paint);

    // Draw bottom-right corner
    canvas.drawLine(Offset(size.width - radius, size.height),
        Offset(size.width - length, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - radius),
        Offset(size.width, size.height - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
