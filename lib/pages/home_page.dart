import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app12/auth/login_signup_page.dart'; // Use this import
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final String username;
  const HomePage({super.key, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  // Design System Colors
  final Color primaryColor = const Color(0xFF2D3748);
  final Color secondaryColor = const Color(0xFF4A5568);
  final Color accentColor = const Color(0xFF4299E1);
  final Color backgroundColor = const Color(0xFFF7FAFC);
  final Color surfaceColor = Colors.white;
  final Color successColor = const Color(0xFF48BB78);
  final Color warningColor = const Color(0xFFED8936);
  final Color errorColor = const Color(0xFFF56565);

  void showAlerts() async {
    QuerySnapshot snapshot = await _db
        .collection("events")
        .orderBy("timestamp", descending: true)
        .limit(10)
        .get();

    final events = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        "time": data["timestamp"]?.toDate() ?? DateTime.now(),
        "image": data["imageUrl"],
        "type": data["type"] ?? "unknown",
      };
    }).toList();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Recent Alerts",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.maxFinite,
                height: 400,
                child: events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: secondaryColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No recent alerts",
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: backgroundColor,
                                    image: event["image"] != null
                                        ? DecorationImage(
                                            image: NetworkImage(event["image"]),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: event["image"] == null
                                      ? Icon(
                                          Icons.image_not_supported,
                                          color: secondaryColor.withOpacity(0.4),
                                        )
                                      : null,
                                ),
                                
                                const SizedBox(width: 16),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event["type"] == "stranger"
                                            ? "Unauthorized Detection"
                                            : "Authorized Entry",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: primaryColor,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 4),
                                      
                                      Text(
                                        event["time"].toString().substring(0, 19),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: event["type"] == "stranger"
                                        ? errorColor.withOpacity(0.1)
                                        : successColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    event["type"] == "stranger"
                                        ? "ALERT"
                                        : "SAFE",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: event["type"] == "stranger"
                                          ? errorColor
                                          : successColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Logout function
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      
      // Navigate back to login page and remove all routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginSignupPage()), // REMOVED const
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // Show error if logout fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout failed: ${e.toString()}"),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  // Confirmation dialog for logout
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Logout",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          "Are you sure you want to logout?",
          style: TextStyle(color: secondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: secondaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _logout(); // Perform logout
            },
            child: Text(
              "Logout",
              style: TextStyle(
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) {
      // Already on home
    } else if (index == 1) {
      // Navigate to Add Faces
      // TODO: Add navigation to Faces page
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Faces page - Coming soon"),
          backgroundColor: accentColor,
        ),
      );
      // Reset index back to Home
      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() => _selectedIndex = 0);
      });
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      ).then((_) {
        setState(() => _selectedIndex = 0);
      });
    } else if (index == 3) {
      // Logout - show confirmation dialog
      _showLogoutConfirmation();
      // Reset index back to Home (will be overridden if logout confirmed)
      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() => _selectedIndex = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome back,",
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.username,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 24),
                      color: primaryColor,
                      onPressed: showAlerts,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Container(
                color: backgroundColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.security,
                          size: 56,
                          color: primaryColor,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Text(
                        "Security System",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        "Active and monitoring",
                        style: TextStyle(
                          fontSize: 16,
                          color: secondaryColor,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: successColor.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: successColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            Text(
                              "All systems operational",
                              style: TextStyle(
                                color: successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onNavTap,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: primaryColor,
            unselectedItemColor: secondaryColor,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
            showUnselectedLabels: true,
            items: [
              BottomNavigationBarItem(
                icon: Icon(
                  _selectedIndex == 0 
                      ? Icons.home_rounded 
                      : Icons.home_outlined,
                  size: 24,
                ),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  _selectedIndex == 1 
                      ? Icons.face_rounded 
                      : Icons.face_outlined,
                  size: 24,
                ),
                label: "Faces",
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  _selectedIndex == 2 
                      ? Icons.settings_rounded 
                      : Icons.settings_outlined,
                  size: 24,
                ),
                label: "Settings",
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  _selectedIndex == 3 
                      ? Icons.logout_rounded 
                      : Icons.logout_outlined,
                  size: 24,
                ),
                label: "Logout",
              ),
            ],
          ),
        ),
      ),
    );
  }
}