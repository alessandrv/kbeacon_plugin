import 'package:flutter/material.dart';
import './screens/HomeScreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
