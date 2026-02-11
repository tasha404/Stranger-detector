import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

import 'package:app12/pages/home_page.dart';

class LoginSignupPage extends StatefulWidget {
  const LoginSignupPage({super.key});

  @override
  State<LoginSignupPage> createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> {
  bool showLogin = true;

  // Colors
  final Color primaryColor = const Color(0xFF2D3748);
  final Color secondaryColor = const Color(0xFF4A5568);
  final Color accentColor = const Color(0xFF4299E1);
  final Color backgroundColor = const Color(0xFFF7FAFC);
  final Color surfaceColor = Colors.white;
  final Color errorColor = const Color(0xFFF56565);

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final familyCodeController = TextEditingController();

  String selectedRole = "";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String generateFamilyCode({int length = 6}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  void showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Error", style: TextStyle(color: primaryColor)),
        content: Text(message, style: TextStyle(color: secondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  // Helper function to navigate to home
  void _navigateToHome(String username) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(username: username),
      ),
    );
  }

  Future<void> login() async {
    try {
      String username = usernameController.text.trim();
      String password = passwordController.text.trim();
      String enteredFamilyCode = familyCodeController.text.trim();

      if (username.isEmpty || password.isEmpty || enteredFamilyCode.isEmpty) {
        showErrorPopup("All fields are required");
        return;
      }

      QuerySnapshot snapshot = await _db
          .collection("users")
          .where("username", isEqualTo: username)
          .get();

      if (snapshot.docs.isEmpty) {
        showErrorPopup("Username not found");
        return;
      }

      var userData = snapshot.docs.first.data() as Map<String, dynamic>;
      String email = userData["email"];
      String storedFamilyCode = userData["familyCode"] ?? "";

      if (userData["role"] == "member" && enteredFamilyCode != storedFamilyCode) {
        showErrorPopup("Incorrect family code");
        return;
      }

      try {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        _navigateToHome(username);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password') {
          showErrorPopup("Incorrect password");
        } else {
          showErrorPopup("Login error: ${e.message}");
        }
      }
    } catch (e) {
      showErrorPopup(e.toString());
    }
  }

  Future<void> signup() async {
    try {
      if (selectedRole.isEmpty) {
        showErrorPopup("Please select a role");
        return;
      }

      String username = usernameController.text.trim();
      String email = emailController.text.trim();
      String password = passwordController.text.trim();

      if (username.isEmpty || email.isEmpty || password.isEmpty) {
        showErrorPopup("All fields are required");
        return;
      }

      if (password.length < 6) {
        showErrorPopup("Password must be at least 6 characters");
        return;
      }

      String familyCode = selectedRole == "homeowner" ? generateFamilyCode() : "";

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text("Creating account..."),
            ],
          ),
        ),
      );

      try {
        // Step 1: Create user in Firebase Authentication
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final userId = userCredential.user!.uid;

        // Step 2: Create user document in Firestore
        await _db.collection("users").doc(userId).set({
          "username": username,
          "email": email,
          "familyCode": familyCode,
          "role": selectedRole,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

        // Close loading dialog
        Navigator.pop(context);

        // If homeowner, show family code BEFORE navigation
        if (selectedRole == "homeowner") {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("Family Code Generated", style: TextStyle(color: primaryColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your family code is:",
                    style: TextStyle(color: secondaryColor),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor),
                    ),
                    child: Center(
                      child: Text(
                        familyCode,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Share this code with family members so they can join.",
                    style: TextStyle(color: secondaryColor, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Important: Save this code! You cannot retrieve it later.",
                    style: TextStyle(
                      color: errorColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToHome(username);
                  },
                  child: Text("Continue", style: TextStyle(color: accentColor)),
                ),
              ],
            ),
          );
        } else {
          // For family members, navigate directly
          _navigateToHome(username);
        }

      } on FirebaseAuthException catch (e) {
        Navigator.pop(context); // Close loading
        
        if (e.code == 'weak-password') {
          showErrorPopup("The password provided is too weak.");
        } else if (e.code == 'email-already-in-use') {
          showErrorPopup("An account already exists for that email.");
        } else if (e.code == 'invalid-email') {
          showErrorPopup("Invalid email address.");
        } else {
          showErrorPopup("Auth error: ${e.message}");
        }
      }

    } catch (e) {
      // Close loading if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      showErrorPopup("Unexpected error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo/Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.security,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
              ),
              
              // Title
              Text(
                showLogin ? "Welcome Back" : "Create Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                showLogin 
                  ? "Sign in to continue monitoring"
                  : "Set up your security account",
                style: TextStyle(
                  fontSize: 16,
                  color: secondaryColor,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Form
              _buildInputField(
                controller: usernameController,
                label: "Username",
                icon: Icons.person_outline,
              ),
              
              const SizedBox(height: 16),
              
              if (!showLogin)
                Column(
                  children: [
                    _buildInputField(
                      controller: emailController,
                      label: "Email",
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              
              _buildInputField(
                controller: passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                obscure: true,
              ),
              
              const SizedBox(height: 16),
              
              if (showLogin)
                _buildInputField(
                  controller: familyCodeController,
                  label: "Family Code",
                  icon: Icons.group_outlined,
                ),
              
              if (!showLogin) ...[
                const SizedBox(height: 24),
                Text(
                  "Select Role",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRoleChip("homeowner"),
                    _buildRoleChip("member"),
                  ],
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: showLogin ? login : signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    showLogin ? "Sign In" : "Create Account",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Toggle
              Center(
                child: TextButton(
                  onPressed: () => setState(() => showLogin = !showLogin),
                  child: Text(
                    showLogin 
                      ? "Don't have an account? Sign up" 
                      : "Already have an account? Sign in",
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: primaryColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: secondaryColor),
        prefixIcon: Icon(icon, color: secondaryColor.withOpacity(0.6)),
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final bool active = selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? primaryColor : surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? primaryColor : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            if (!active)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          role == "homeowner" ? "Homeowner" : "Family Member",
          style: TextStyle(
            color: active ? Colors.white : secondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}