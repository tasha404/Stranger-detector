// pages/settings_page.dart
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'family_members_page.dart';
import 'notifications_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  
  // Minimal blue/gray colors
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color lightBlue = const Color(0xFFE3F2FD);
  final Color darkGray = const Color(0xFF424242);
  final Color mediumGray = const Color(0xFF757575);
  final Color lightGray = const Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: darkGray,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: darkGray),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section: Account
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  "ACCOUNT",
                  style: TextStyle(
                    color: mediumGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              
              _buildSettingsTile(
                context: context,
                icon: Icons.person_outline,
                title: "Profile",
                subtitle: "Manage your account",
                page: const ProfilePage(),
              ),
              
              _buildSettingsTile(
                context: context,
                icon: Icons.group_outlined,
                title: "Family Members",
                subtitle: "Manage access permissions",
                page: const FamilyMembersPage(),
              ),
              
              const SizedBox(height: 24),
              
              // Section: Security
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  "SECURITY",
                  style: TextStyle(
                    color: mediumGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              
              _buildSettingsTile(
                context: context,
                icon: Icons.notifications_outlined,
                title: "Notifications",
                subtitle: "View security alerts",
                page: const NotificationsPage(),
              ),
              
              const SizedBox(height: 24),
              
              // Section: System
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  "SYSTEM",
                  style: TextStyle(
                    color: mediumGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              
              _buildSettingsItem(
                icon: Icons.storage_outlined,
                title: "Storage",
                subtitle: "Manage recorded footage",
              ),
              
              _buildSettingsItem(
                icon: Icons.device_hub_outlined,
                title: "Devices",
                subtitle: "Connected cameras",
              ),
              
              const SizedBox(height: 32),
              
              // App Version
              Center(
                child: Text(
                  "Version 1.0.0",
                  style: TextStyle(
                    color: mediumGray,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: lightGray),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: lightBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryBlue, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: darkGray,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: mediumGray, fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: mediumGray),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: lightGray),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: lightBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryBlue, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: darkGray,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: mediumGray, fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: mediumGray),
        onTap: () {
          // Add functionality here
        },
      ),
    );
  }
}