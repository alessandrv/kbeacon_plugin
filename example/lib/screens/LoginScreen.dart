import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For JSON encoding/decoding
import 'package:http/http.dart' as http; // For making HTTP requests

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
    await prefs.remove('username');
    await prefs.remove('serverAddress');
    await prefs.remove('password');
    await prefs.remove('savePassword');

    setState(() {
      _token = null;
      _role = null;
      _username = null;
      _isLoggedIn = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
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
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
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
                          Text('Username: $_username', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Role: $_role', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            'Token: $_token',
                            style: const TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Esegui l\'accesso',
                          style: TextStyle(fontSize: 16),
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
                  minimumSize: const Size.fromHeight(50), // Make button full width
                ),
              )
            else
              ElevatedButton(
                onPressed: _navigateToLogin,
                child: const Text('Login'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50), // Make button full width
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// LoginScreen: The new login screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _serverAddressController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _savePassword = false; // Checkbox flag
  bool _isLoading = false; // Loading indicator

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Load saved server address, username, password
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

    try {
      final url = Uri.parse('$serverAddress/login');
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful')),
          );
          Navigator.pop(context, true); // Indicate successful login
        }
      } else {
        if (!autoLogin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed')),
          );
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
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _serverAddressController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Server Address',
                      hintText: 'https://yourserver.com',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Username',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Password',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _savePassword,
                        onChanged: (bool? value) {
                          setState(() {
                            _savePassword = value ?? false;
                          });
                        },
                      ),
                      const Text('Save password'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the login screen
                        },
                        child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _login(),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
