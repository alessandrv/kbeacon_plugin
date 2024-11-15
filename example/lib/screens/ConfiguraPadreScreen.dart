import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './DeviceSelectionScreen.dart';
import './AssociaProvaScreen.dart';
import 'package:kbeacon_plugin_example/utils/notification_helper.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class ConfiguraPadreScreen extends StatefulWidget {
  const ConfiguraPadreScreen({super.key});

  @override
  State<ConfiguraPadreScreen> createState() => _ConfiguraPadreScreenState();
}

class _ConfiguraPadreScreenState extends State<ConfiguraPadreScreen> {
  bool _isLoggedIn = false;
  String? _role;
  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  final GlobalKey _wifiKey = GlobalKey();
  final GlobalKey _associaProvaKey = GlobalKey();
  final GlobalKey _registraKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchLoginStatus();
    _initTargets();
  }

   void _initTargets() {
    targets = [
      TargetFocus(
        identify: "WiFi Key",
        keyTarget: _wifiKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTargetContent(
                "Connetti alla rete",
                "Connetti il dispositivo alla rete, generalmente usato per collegarsi all'hotspot del proprio telefono.",
                Icons.wifi,
                onTap: () => controller.next(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Associa Prova Key",
        keyTarget: _associaProvaKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTargetContent(
                "Associa una prova al padre",
                "Usato per associare al padre attraverso il suo ID la prova di una manifestazione specifica, fondamentale per la corretta registrazione dei tempi. Richiede di aver effettuato l'accesso",
                Icons.timer_outlined,
                onTap: () => controller.next(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Registra Key",
        keyTarget: _registraKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTargetContent(
                "Registra dispositivo",
                "Funzione esclusiva per gli admin del sistema, necessaria per registrare un dispositivo padre sul database per permettere di associare le prove al dispositivo registrato. Meccanismo per evitare l'associazione di un dispositivo non esistente ad una prova.",
                Icons.assignment_add,
                onTap: () => controller.next(),
              );
            },
          ),
        ],
      ),
    ];
  }

  Widget _buildTargetContent(String title, String description, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 24),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(color: Colors.black87, fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              "Tocca qui o l'area evidenziata per proseguire",
              style: TextStyle(color: Colors.black54, fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  void _showTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black87,
      textSkip: "Salta",
      paddingFocus: 10,
      opacityShadow: 0.8,
       focusAnimationDuration: Duration(milliseconds: 100),
      pulseAnimationDuration: Duration(milliseconds: 300),
      unFocusAnimationDuration: Duration(milliseconds: 300),
     
      onFinish: () {
        print("Tutorial finished");
      },
      onClickTarget: (target) {
        print('Clicked on ${target.identify}');
      },
      onClickOverlay: (target) {
        print('Clicked on overlay');
      },
      onSkip: () {
        print("Tutorial skipped");
        return true; // Dismiss the tutorial when skipped
      },
    )..show(context: context);
  }
  Future<void> _fetchLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    setState(() {
      _isLoggedIn = token != null && role != null;
      _role = role;
    });
  }

  Widget _buildDashboardTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEnabled = true,
    Color? backgroundColor,
    double? sizeFactor,
    ShapeBorder? shape,
    Key? key,
  }) {
    final bool isDarkBackground =
        backgroundColor != null && backgroundColor != Colors.white;
    final Color textColor = isDarkBackground ? Colors.white : Colors.black87;
    final Color subtitleColor =
        isDarkBackground ? Colors.white70 : Colors.black54;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: Material(
        key: key,
        color: isEnabled
            ? (backgroundColor ?? Colors.white)
            : Colors.grey[300],
        shape: shape ?? RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          customBorder: shape ?? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: shape is RoundedRectangleBorder
                  ? (shape as RoundedRectangleBorder).borderRadius
                  : null,
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: sizeFactor != null ? 60 * sizeFactor : 40,
                  color: isEnabled ? textColor : Colors.grey[600],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: sizeFactor != null ? 20 * sizeFactor : 16,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? textColor : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: sizeFactor != null ? 14 * sizeFactor : 12,
                    color: isEnabled ? subtitleColor : Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showTutorial,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                flex: 7,
                child: _buildDashboardTile(
                  key: _wifiKey,
                  icon: Icons.wifi,
                  title: 'Connetti al WiFi',
                  subtitle: 'Connect and configure your device via WiFi.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DeviceSelectionScreen()),
                    );
                  },
                  isEnabled: true,
                  backgroundColor: Theme.of(context).primaryColor,
                  sizeFactor: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22.0),
                    side: BorderSide(
                      color: Theme.of(context).splashColor,
                      width: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDashboardTile(
                        key: _associaProvaKey,
                        icon: Icons.timer_outlined,
                        title: 'Associa Prova',
                        subtitle: 'Associate a test.',
                        onTap: _isLoggedIn
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AssociaProvaScreen()),
                                );
                              }
                            : () {
                                showNotification(context, 'Effettua il login per associare la prova', false);
                              },
                        backgroundColor: Theme.of(context).splashColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDashboardTile(
                        key: _registraKey,
                        icon: Icons.assignment_add,
                        title: 'Registra',
                        subtitle: 'Register to the database.',
                        onTap: (_isLoggedIn && _role == 'admin')
                            ? () {
                                showNotification(context, "Funzione non implementata", false);
                              }
                            : () {
                                showNotification(context, 'Solo un utente admin può registrare un nuovo prodotto a sistema', false);
                              },
                        backgroundColor: Theme.of(context).splashColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}