// pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'ios_notification_banner.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final String type;
  final String? location;
  final String? person;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.location,
    this.person,
    this.isRead = false,
  });
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationItem> notifications = [
    NotificationItem(
      id: '1',
      title: 'Unauthorized Face Detected',
      message: 'Unknown person detected',
      time: DateTime.now().subtract(const Duration(minutes: 5)),
      type: 'unauthorized',
      location: 'Front Door',
    ),
    NotificationItem(
      id: '2',
      title: 'Motion Detected',
      message: 'Movement detected',
      time: DateTime.now().subtract(const Duration(minutes: 15)),
      type: 'motion',
      location: 'Living Room',
    ),
    NotificationItem(
      id: '3',
      title: 'Authorized Entry',
      message: 'Family member entered',
      time: DateTime.now().subtract(const Duration(minutes: 30)),
      type: 'authorized',
      person: 'Alice Smith',
    ),
  ];

  void _dismissNotification(String id) {
    setState(() {
      notifications.removeWhere((n) => n.id == id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification dismissed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (var n in notifications) {
        n.isRead = true;
      }
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Clear All Notifications?'),
        content: const Text('This will remove all notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => notifications.clear());
              Navigator.pop(context);
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner(NotificationItem notification) {
    final timeAgo = _getTimeAgo(notification.time);

    switch (notification.type) {
      case 'unauthorized':
        return UnauthorizedFaceBanner(
          location: notification.location ?? 'Unknown location',
          time: timeAgo,
          onTap: () => setState(() => notification.isRead = true),
        );
      case 'motion':
        return MotionDetectedBanner(
          location: notification.location ?? 'Unknown location',
          time: timeAgo,
          onTap: () => setState(() => notification.isRead = true),
        );
      case 'authorized':
        return AuthorizedEntryBanner(
          person: notification.person ?? 'Family Member',
          time: timeAgo,
          onTap: () => setState(() => notification.isRead = true),
        );
      default:
        return IOSNotificationBanner(
          title: notification.title,
          message: '${notification.message} • $timeAgo',
          icon: Icons.notifications_none_rounded,
          color: const Color(0xFF3B82F6), // soft blue accent
          onTap: () => setState(() => notification.isRead = true),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // light blue-gray
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: notifications.isNotEmpty ? _clearAll : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${notifications.length} Notifications',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unreadCount unread',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Notification list
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 70,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];

                      return Dismissible(
                        key: Key(notification.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) =>
                            _dismissNotification(notification.id),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6),
                          child:
                              _buildNotificationBanner(notification),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${difference.inDays ~/ 7}w ago';
  }
}
