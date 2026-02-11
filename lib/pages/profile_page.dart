import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  
  bool isLoading = true;
  String? errorMessage;
  
  // Minimal blue/gray colors
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color lightBlue = const Color(0xFFE3F2FD);
  final Color darkGray = const Color(0xFF424242);
  final Color mediumGray = const Color(0xFF757575);
  final Color lightGray = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final User? user = _auth.currentUser;
      
      if (user == null) {
        setState(() {
          errorMessage = "Please sign in to view profile";
          isLoading = false;
        });
        return;
      }
      
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (doc.exists) {
        final data = doc.data();
        usernameController.text = data?['username'] ?? '';
      } else {
        usernameController.text = '';
      }
      
      emailController.text = user.email ?? '';
      setState(() => isLoading = false);
      
    } catch (e) {
      setState(() {
        errorMessage = "Error loading profile";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: primaryBlue),
        ),
      );
    }
    
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            "Profile",
            style: TextStyle(color: darkGray, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: darkGray),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: mediumGray),
                const SizedBox(height: 20),
                Text(
                  errorMessage!,
                  style: TextStyle(fontSize: 16, color: darkGray),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadUserData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightBlue,
                    foregroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: primaryBlue.withOpacity(0.3)),
                    ),
                    elevation: 0,
                  ),
                  child: Text("Try Again", style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Profile",
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryBlue, width: 2),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    usernameController.text.isNotEmpty 
                        ? usernameController.text 
                        : "Set username",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: darkGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emailController.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: mediumGray,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Account Information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: lightGray),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Account Information",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: darkGray,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Username Field
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: "Username",
                      labelStyle: TextStyle(color: mediumGray),
                      prefixIcon: Icon(Icons.person, color: primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryBlue),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Email Field (read-only)
                  TextFormField(
                    controller: emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: TextStyle(color: mediumGray),
                      prefixIcon: Icon(Icons.email, color: primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: lightGray),
                      ),
                      filled: true,
                      fillColor: lightGray,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _firestore
                              .collection('users')
                              .doc(_auth.currentUser!.uid)
                              .update({
                            'username': usernameController.text.trim(),
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Username updated"),
                              backgroundColor: primaryBlue,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: ${e.toString()}"),
                              backgroundColor: Colors.red.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Update Profile",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Account Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: lightGray),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Account Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: darkGray,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.fingerprint, color: primaryBlue),
                    title: Text(
                      "User ID",
                      style: TextStyle(color: mediumGray, fontSize: 14),
                    ),
                    subtitle: Text(
                      _auth.currentUser?.uid != null 
                          ? "${_auth.currentUser!.uid.substring(0, 8)}..." 
                          : "N/A",
                      style: TextStyle(color: darkGray, fontSize: 12),
                    ),
                  ),
                  
                  Divider(color: lightGray),
                  
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.verified, color: primaryBlue),
                    title: Text(
                      "Email Status",
                      style: TextStyle(color: mediumGray, fontSize: 14),
                    ),
                    subtitle: Text(
                      _auth.currentUser?.emailVerified ?? false 
                          ? "Verified" 
                          : "Not verified",
                      style: TextStyle(
                        color: _auth.currentUser?.emailVerified ?? false 
                            ? Colors.green.shade600 
                            : Colors.orange.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}