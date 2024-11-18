import 'package:flutter/material.dart';
import 'package:kbeacon_plugin_example/screens/FiglioLogScreen.dart';
import 'package:kbeacon_plugin_example/screens/FiglioScreen.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import './ConfiguraPadreScreen.dart'; // Import the ConfiguraPadreScreen
import 'BeaconScreen.dart'; // Import BeaconScreen
import './ImpostazioniScreen.dart'; // Import ImpostazioniScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Create a PageController to control the pages
  final PageController _pageController = PageController();

  // List of screens for each tab
final List<Widget> _screens = [
  const ConfiguraPadreScreen(),
  const BeaconScreen(),
  const FiglioScreen(),            // Removed 'const' here
  const ImpostazioniScreen(),
];


  @override
  void dispose() {
    _pageController.dispose(); // Dispose the controller when not needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set the main background color to the primary color
      backgroundColor: Theme.of(context).primaryColor,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _screens.length,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
              }
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: _screens[index],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SalomonBottomBar(
        backgroundColor: Theme.of(context).primaryColor, // Set background to primary color
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white, // Set selected items to white
        unselectedItemColor: Colors.white70, // Set unselected items to white
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _pageController.jumpToPage(index); // Use jumpToPage for instant transition
          });
        },
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.cell_tower),
            title: const Text("Padre"),
            // Removed selectedColor
          ),
        SalomonBottomBarItem(
            icon: Image.asset(
              'assets/images/beacon_image.png', // Path to your image
              width: 24, // Set the width of the icon
              height: 24, // Set the height of the icon
            ),
            title: const Text("Beacon"),
          ),

          SalomonBottomBarItem(
            icon: const Icon(Icons.cable),
            title: const Text("Figlio"),
            // Removed selectedColor
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.settings),
            title: const Text("Impostazioni"),
            // Removed selectedColor
          ),
        ],
      ),
    );
  }
}

// Placeholder screen for features not yet implemented
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ensure the PlaceholderScreen also has the primary color as background
      backgroundColor: Theme.of(context).primaryColor,
      body: const Center(
        child: Icon(Icons.cable, size: 100, color: Colors.white), // Changed color to white for visibility
      ),
    );
  }
}
