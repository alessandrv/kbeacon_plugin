import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For JSON encoding/decoding
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:kbeacon_plugin_example/utils/notification_helper.dart'; // Adjust the path to your project's structure

// Main function to run the app
void main() {
  runApp(const MyApp());
}

// Root of the application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impostazioni App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Define default font family
        fontFamily: 'Roboto',
        // Define default input decoration theme
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.black,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
      home: const ImpostazioniScreen(),
    );
  }
}

// ImpostazioniScreen: The settings screen
class ImpostazioniScreen extends StatefulWidget {
  const ImpostazioniScreen({super.key});

  @override
  State<ImpostazioniScreen> createState() => _ImpostazioniScreenState();
}

class _ImpostazioniScreenState extends State<ImpostazioniScreen> {
  String? _token;
  String? _role;
  String? _username;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadLoginStatus(); // Load login status and attempt automatic login
  }

  // Load the saved token, role, and username from SharedPreferences
  Future<void> _loadLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');
    final username = prefs.getString('username');

    setState(() {
      _token = token;
      _role = role;
      _username = username;
      _isLoggedIn = token != null && role != null && username != null;
    });
  }

  // Log out the user by clearing SharedPreferences
  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');

    await prefs.remove('password');
    await prefs.remove('savePassword');

    setState(() {
      _token = null;
      _role = null;
      _username = null;
      _isLoggedIn = false;
    });

             showNotification(context, 'Disconnesso', true);

  }

  // Navigate to the LoginScreen and await the result
  Future<void> _navigateToLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    if (result == true) {
      // If login was successful, reload the login status
      _loadLoginStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            backgroundColor: Theme.of(context).primaryColor,

      appBar: AppBar(
              backgroundColor: Theme.of(context).primaryColor,

      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).splashColor,

              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                
                padding: const EdgeInsets.all(16.0),
                child: _isLoggedIn
                    ? Column(
                      
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Username: $_username',
                              style: const TextStyle(color: Colors.white,fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Role: $_role',
                              style: const TextStyle(color: Colors.white,fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            'Token: $_token',
                            style:
                                const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Esegui l\'accesso',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoggedIn)
              ElevatedButton(
                onPressed: _logout,
                child: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).splashColor,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      elevation: 5,
                    ),
              )
            else
             ElevatedButton(
                onPressed: _navigateToLogin,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).splashColor,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
          ],
        ),
      ),
    );
  }
}
// LoginScreen: The new login screen with enhanced design
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _serverAddressController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _savePassword = false; // Checkbox flag
  bool _isLoading = false; // Loading indicator

  // Animation controller for button
  late AnimationController _animationController;
  late Animation<double> _buttonSqueezeAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Load saved server address, username, password

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonSqueezeAnimation = Tween<double>(begin: 320.0, end: 50.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.0,
          0.250,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _serverAddressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Load saved server address, username, and password
  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverAddressController.text = prefs.getString('serverAddress') ?? '';
      _usernameController.text = prefs.getString('username') ?? '';
      if (prefs.getBool('savePassword') ?? false) {
        _passwordController.text = prefs.getString('password') ?? '';
        _savePassword = true;
      }
    });
  }

  // Save the login information to SharedPreferences
  Future<void> _saveLoginStatus(String token, String role, String username) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', role);
    await prefs.setString('username', username);
    await prefs.setString('serverAddress', _serverAddressController.text);

    if (_savePassword) {
      await prefs.setString('password', _passwordController.text);
    } else {
      await prefs.remove('password');
    }
    await prefs.setBool('savePassword', _savePassword);
  }

  // Log in the user by making a POST request to the login API
  Future<void> _login({bool autoLogin = false}) async {
    final serverAddress = _serverAddressController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (!autoLogin && (serverAddress.isEmpty || username.isEmpty || password.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Start button animation
    if (!autoLogin) {
      _animationController.forward();
    }

    try {
      final url = Uri.parse('$serverAddress/login-app');
      final response = await http.post(
        url,
        body: jsonEncode({'username': username, 'password': password}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final role = data['role'];

        await _saveLoginStatus(token, role, username);

        if (!autoLogin) {
          showNotification(context, 'Login avvenuto', true);

        
          Navigator.pop(context, true); // Indicate successful login
        }
      } else {
        if (!autoLogin) {
                 showNotification(context, 'Login fallito', false);

        }
      }
    } catch (e) {
      if (!autoLogin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      // Reverse button animation
      if (!autoLogin) {
        _animationController.reverse();
      }
    }
  }

  // Handle automatic login after loading saved credentials
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Attempt auto login if credentials are saved
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('savePassword') ?? false) {
      await _login(autoLogin: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set the scaffold's background color to primary color
      backgroundColor: Theme.of(context).primaryColor,
      // Use a Stack to place background color and content
      body: Stack(
        children: [
          // Removed the gradient and set background color via Scaffold
          // Content with padding and scroll
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo or Image
                SizedBox(
                  height: 150,
                  child: Image.asset(
                    'assets/logo.png', // Ensure you have a logo image in assets
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                const Text(
                  'Benvenuto',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white, // Changed to white for contrast
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                // Subtitle
                const Text(
                  'Effettua il login',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70, // Changed to white70 for contrast
                  ),
                ),
                const SizedBox(height: 30),
                // Server Address TextField
               TextField(
  controller: _serverAddressController,
  decoration: InputDecoration(
    hintText: 'Indirizzo server',
   
    prefixIcon: Icon(
      Icons.cloud,
      color: Colors.white,
    ),
    filled: true,
    fillColor: Colors.white10, // Background color of the TextField
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none, // Removes the border
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
  ),
  style: TextStyle(
    color: Colors.white, // Sets the input text color to white
    // You can also customize other text properties here
  ),
),

                const SizedBox(height: 20),
                // Username TextField
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'Username',
                    prefixIcon: Icon(
                      Icons.person,
                      color: Colors.white,
                    ),
                    filled: true,
                    fillColor: Colors.white10, // Changed to white for better contrast
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none, // No border
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  ),
                   style: TextStyle(
    color: Colors.white, // Sets the input text color to white
    // You can also customize other text properties here
  ),
                ),
                const SizedBox(height: 20),
                // Password TextField
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icon(
                      Icons.lock,
                      color: Colors.white,
                    ),
                    filled: true,
                    fillColor: Colors.white10, // Changed to white for better contrast
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none, // No border
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  ),
                  obscureText: true,
                   style: TextStyle(
    color: Colors.white, // Sets the input text color to white
    // You can also customize other text properties here
  ),
                ),
               
                const SizedBox(height: 30),
                // Login Button with animation
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _login(),
                    style: ElevatedButton.styleFrom(
                                            side: const BorderSide(color: Colors.white),

                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).splashColor,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      elevation: 5,
                    ),
                    child: _isLoading
                        ? SpinKitRipple(
                            color: Colors.white,
                          )
                        :  Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                             
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // Cancel Button
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the login screen
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Additional Links or Information
              ],
            ),
          ),
        ],
      ),
    );
  }
}
