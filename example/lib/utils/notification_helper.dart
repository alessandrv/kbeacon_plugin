import 'package:flutter/material.dart';

void showNotification(BuildContext context, String message, bool isSuccess) {
  OverlayEntry? overlayEntry;

  // Define the widget with fade-in and fade-out animations
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 50.0, // Position at the bottom of the screen
      left: MediaQuery.of(context).size.width * 0.1,
      right: MediaQuery.of(context).size.width * 0.1,
      child: _FadeInFadeOutNotification(
        message: message,
        isSuccess: isSuccess,
        onClose: () {
          // Remove the overlay after fade-out
          overlayEntry?.remove();
        },
      ),
    ),
  );

  // Insert the overlay entry into the overlay
  Overlay.of(context)?.insert(overlayEntry);
}

// Custom widget with fade-in and fade-out behavior, now with Dismissible support
class _FadeInFadeOutNotification extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onClose;

  const _FadeInFadeOutNotification({
    Key? key,
    required this.message,
    required this.isSuccess,
    required this.onClose,
  }) : super(key: key);

  @override
  State<_FadeInFadeOutNotification> createState() => __FadeInFadeOutNotificationState();
}

class __FadeInFadeOutNotificationState extends State<_FadeInFadeOutNotification> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Fade-in and fade-out duration
    );

    // Start fade-in
    _animationController.forward();

    // Automatically fade-out after 3 seconds if not dismissed by the user
    Future.delayed(const Duration(seconds: 3), () {
      _fadeOutAndRemove();
    });
  }

  void _fadeOutAndRemove() {
    // Fade out and trigger the onClose callback
    if (mounted) {
      _animationController.reverse().then((_) {
        widget.onClose(); // Remove the overlay
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.horizontal, // User can swipe up to dismiss the notification
      onDismissed: (direction) {
        _fadeOutAndRemove(); // Trigger fade out and remove on swipe
      },
      child: FadeTransition(
        opacity: _animationController,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: widget.isSuccess ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with circular background
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isSuccess ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Message
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
