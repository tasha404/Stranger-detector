// services/face_storage_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FaceStorageService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Maximum images per member
  static const int maxImagesPerMember = 3;

  // Add new family member with face image (SINGLE IMAGE VERSION)
  Future<void> addFamilyMember({
    required String name,
    required String role,
    required File faceImage, // Changed from List<File> to single File
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload image
      final imageUrl = await _uploadFaceImage(
        imageFile: faceImage,
        memberName: name,
        imageIndex: 1,
      );

      // Add to Firestore with single image array
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .add({
            'name': name,
            'role': role,
            'faceImages': [imageUrl], // Single image in array
            'latestFaceUrl': imageUrl,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'imageCount': 1,
          });

    } catch (e) {
      print('Add family member error: $e');
      rethrow;
    }
  }

  // Add more face images to existing member (for adding 2nd/3rd images)
  Future<void> addMoreFaceImages({
    required String memberId,
    required List<File> newFaceImages,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get current member data
      final memberDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .doc(memberId)
          .get();

      if (!memberDoc.exists) {
        throw Exception('Family member not found');
      }

      final data = memberDoc.data()!;
      final currentImages = List<String>.from(data['faceImages'] ?? []);
      final currentCount = currentImages.length;

      // Check if adding would exceed limit
      if (currentCount + newFaceImages.length > maxImagesPerMember) {
        throw Exception('Cannot exceed $maxImagesPerMember images. Current: $currentCount, Adding: ${newFaceImages.length}');
      }

      // Upload new images
      final List<String> newImageUrls = [];
      for (var i = 0; i < newFaceImages.length; i++) {
        final imageUrl = await _uploadFaceImage(
          imageFile: newFaceImages[i],
          memberName: data['name'],
          imageIndex: currentCount + i + 1,
        );
        newImageUrls.add(imageUrl);
      }

      // Update Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .doc(memberId)
          .update({
            'faceImages': FieldValue.arrayUnion(newImageUrls),
            'latestFaceUrl': newImageUrls.last,
            'updatedAt': FieldValue.serverTimestamp(),
            'imageCount': currentCount + newFaceImages.length,
          });

    } catch (e) {
      print('Add more face images error: $e');
      rethrow;
    }
  }

  // Update/Replace family member's face image (for updating existing image)
  Future<void> updateFamilyMemberFace({
    required String memberId,
    required File newFaceImage, // Changed parameter name
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get current member data
      final memberDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .doc(memberId)
          .get();

      if (!memberDoc.exists) {
        throw Exception('Family member not found');
      }

      final data = memberDoc.data()!;
      final currentImages = List<String>.from(data['faceImages'] ?? []);
      final memberName = data['name'];

      if (currentImages.isEmpty) {
        throw Exception('No existing images to update');
      }

      // Upload new image
      final newImageUrl = await _uploadFaceImage(
        imageFile: newFaceImage,
        memberName: memberName,
        imageIndex: currentImages.length + 1,
        isUpdate: true,
      );

      // Delete the oldest image if we have max images
      if (currentImages.length >= maxImagesPerMember) {
        await _deleteImageFromStorage(currentImages.first);
        currentImages.removeAt(0);
      }

      // Add new image
      currentImages.add(newImageUrl);

      // Update Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .doc(memberId)
          .update({
            'faceImages': currentImages,
            'latestFaceUrl': newImageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
            'imageCount': currentImages.length,
          });

    } catch (e) {
      print('Update face image error: $e');
      rethrow;
    }
  }

  // Delete specific face image
  Future<void> deleteFaceImage({
    required String memberId,
    required int imageIndex,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get current member data
      final memberDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .doc(memberId)
          .get();

      if (!memberDoc.exists) {
        throw Exception('Family member not found');
      }

      final data = memberDoc.data()!;
      final currentImages = List<String>.from(data['faceImages'] ?? []);

      if (imageIndex >= currentImages.length) {
        throw Exception('Image index out of range');
      }

      // Check minimum images requirement
      if (currentImages.length <= 1) {
        throw Exception('Cannot delete the last image. Minimum 1 image required.');
      }

      // Get image URL to delete
      final imageUrlToDelete = currentImages[imageIndex];

      // Delete from storage
      await _deleteImageFromStorage(imageUrlToDelete);

      // Remove from array
      currentImages.removeAt(imageIndex);

      // Update Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .doc(memberId)
          .update({
            'faceImages': currentImages,
            'latestFaceUrl': currentImages.isNotEmpty ? currentImages.last : '',
            'updatedAt': FieldValue.serverTimestamp(),
            'imageCount': currentImages.length,
          });

    } catch (e) {
      print('Delete face image error: $e');
      rethrow;
    }
  }

  // Delete entire family member
  Future<void> deleteFamilyMember(String memberId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get member data to delete images from storage
      final memberDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .doc(memberId)
          .get();

      if (memberDoc.exists) {
        final data = memberDoc.data()!;
        final faceImages = List<String>.from(data['faceImages'] ?? []);

        // Delete all images from storage
        for (final imageUrl in faceImages) {
          await _deleteImageFromStorage(imageUrl);
        }

        // Delete document from Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('family_members')
            .doc(memberId)
            .delete();
      }

    } catch (e) {
      print('Delete family member error: $e');
      rethrow;
    }
  }

  // Get all family members
  Stream<QuerySnapshot> getFamilyMembersStream() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('family_members')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get single family member
  Future<DocumentSnapshot> getFamilyMember(String memberId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    return await _firestore
        .collection('users')
        .doc(user.uid)
          .collection('family_members')
        .doc(memberId)
        .get();
  }

  // Private helper methods
  Future<String> _uploadFaceImage({
    required File imageFile,
    required String memberName,
    required int imageIndex,
    bool isUpdate = false,
  }) async {
    final user = _auth.currentUser!;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Create organized folder structure
    final fileName = '${memberName.replaceAll(' ', '_')}_${isUpdate ? 'update' : 'image'}_$imageIndex.jpg';
    final ref = _storage.ref().child(
      'family_faces/${user.uid}/${memberName.replaceAll(' ', '_')}/$fileName'
    );

    // Upload with metadata
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploadedBy': user.uid,
        'memberName': memberName,
        'imageIndex': imageIndex.toString(),
        'uploadedAt': timestamp.toString(),
      },
    );

    await ref.putFile(imageFile, metadata);
    return await ref.getDownloadURL();
  }

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Delete image from storage error: $e');
      // Don't rethrow - continue even if storage deletion fails
    }
  }

  // Get available slots for more images
  Future<int> getAvailableImageSlots(String memberId) async {
    try {
      final memberDoc = await getFamilyMember(memberId);
      if (!memberDoc.exists) return 0;

      final data = memberDoc.data() as Map<String, dynamic>;
      final currentCount = (data['imageCount'] as int? ?? 0);
      
      return maxImagesPerMember - currentCount;
    } catch (e) {
      return 0;
    }
  }
}