import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class PiFaceService {
  // Update this with your Raspberry Pi's IP address
  static const String _piBaseUrl = 'http://192.168.1.100:5000';
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Test connection to Raspberry Pi
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_piBaseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Pi Connection Error: $e');
      return false;
    }
  }
  
  // Capture face and send to Pi for recognition
  Future<Map<String, dynamic>> recognizeFace(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }
      
      // Step 1: Send to Raspberry Pi
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      print('Sending to Pi for face recognition...');
      
      final response = await http.post(
        Uri.parse('$_piBaseUrl/recognize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      
      if (response.statusCode != 200) {
        return {'success': false, 'error': 'Pi API Error: ${response.statusCode}'};
      }
      
      final piResult = jsonDecode(response.body);
      
      // Step 2: Upload image to Firebase Storage
      final imageUrl = await _uploadImageToStorage(imageFile);
      
      // Step 3: Log event to Firestore
      await _logRecognitionEvent(
        user: user,
        piResult: piResult,
        imageUrl: imageUrl,
      );
      
      return {
        'success': true,
        'person': piResult['person_name'] ?? 'Unknown',
        'confidence': piResult['confidence'] ?? 0.0,
        'imageUrl': imageUrl,
        'type': piResult['person_name'] == 'Unknown' ? 'stranger' : 'authorized',
      };
      
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Register a new family member face
  Future<bool> registerFamilyMemberFace(File imageFile, String name, String role) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await http.post(
        Uri.parse('$_piBaseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'name': name,
          'role': role,
        }),
      );
      
      if (response.statusCode == 200) {
        // Upload to Firebase Storage
        final imageUrl = await _uploadImageToStorage(imageFile);
        
        // Store in Firestore
        await _firestore.collection('family_members').add({
          'name': name,
          'role': role,
          'imageUrl': imageUrl,
          'registeredAt': FieldValue.serverTimestamp(),
          'pi_trained': true,
        });
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Register face error: $e');
      return false;
    }
  }
  
  // Private helper methods
  Future<String> _uploadImageToStorage(File imageFile) async {
    final user = _auth.currentUser;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final ref = _storage.ref().child(
      'face_images/${user!.uid}/$timestamp.jpg'
    );
    
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }
  
  Future<void> _logRecognitionEvent({
    required User user,
    required Map<String, dynamic> piResult,
    required String imageUrl,
  }) async {
    await _firestore.collection('events').add({
      'userId': user.uid,
      'userEmail': user.email,
      'person': piResult['person_name'] ?? 'Unknown',
      'confidence': piResult['confidence'] ?? 0.0,
      'imageUrl': imageUrl,
      'type': piResult['person_name'] == 'Unknown' ? 'stranger' : 'authorized',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
  
  // Get recognition history
  Stream<QuerySnapshot> getRecognitionHistory() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    
    return _firestore
        .collection('events')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}