// widgets/ios_notification_banner.dart
import 'package:flutter/material.dart';

class IOSNotificationBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isDismissible;

  const IOSNotificationBanner({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.onTap,
    this.isDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon with background
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Dismiss button
            if (isDismissible)
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  // Dismiss logic handled by parent
                },
              ),
          ],
        ),
      ),
    );
  }
}

// Specific banner types for different notifications
class UnauthorizedFaceBanner extends StatelessWidget {
  final String location;
  final String time;
  final VoidCallback? onTap;
  
  const UnauthorizedFaceBanner({
    super.key,
    required this.location,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IOSNotificationBanner(
      title: '🚨 Unauthorized Face Detected',
      message: 'Unknown person at $location • $time',
      icon: Icons.security,
      color: const Color(0xFFE74C3C), // Red like iOS alerts
      onTap: onTap,
    );
  }
}

class MotionDetectedBanner extends StatelessWidget {
  final String location;
  final String time;
  final VoidCallback? onTap;
  
  const MotionDetectedBanner({
    super.key,
    required this.location,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IOSNotificationBanner(
      title: '⚠️ Motion Detected',
      message: 'Movement at $location • $time',
      icon: Icons.directions_run,
      color: const Color(0xFFF39C12), // Orange
      onTap: onTap,
    );
  }
}

class AuthorizedEntryBanner extends StatelessWidget {
  final String person;
  final String time;
  final VoidCallback? onTap;
  
  const AuthorizedEntryBanner({
    super.key,
    required this.person,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IOSNotificationBanner(
      title: '✅ $person Entered',
      message: 'Authorized entry • $time',
      icon: Icons.check_circle,
      color: const Color(0xFF2ECC71), // Green
      onTap: onTap,
    );
  }
}