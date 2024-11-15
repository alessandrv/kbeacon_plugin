// dashboard_tile.dart
import 'package:flutter/material.dart';

class DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isEnabled;
  final Color? backgroundColor;
  final double sizeFactor;

  const DashboardTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isEnabled = true,
    this.backgroundColor,
    this.sizeFactor = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      enabled: isEnabled,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isEnabled
                ? (backgroundColor ?? Colors.white)
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
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
                size: 40 * sizeFactor,
                color: isEnabled
                    ? (backgroundColor != null
                        ? Colors.white
                        : Theme.of(context).primaryColor)
                    : Colors.grey[600],
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16 * sizeFactor,
                  fontWeight: FontWeight.bold,
                  color: isEnabled
                      ? (backgroundColor != null ? Colors.white : Colors.black)
                      : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12 * sizeFactor,
                  color: isEnabled
                      ? (backgroundColor != null
                          ? Colors.white70
                          : Colors.grey[700])
                      : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
