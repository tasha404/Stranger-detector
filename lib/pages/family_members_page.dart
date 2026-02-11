import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app12/pages/face_detection_page.dart';
import 'package:app12/services/face_storage_service.dart';

class FamilyMembersPage extends StatefulWidget {
  const FamilyMembersPage({super.key});

  @override
  State<FamilyMembersPage> createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FaceStorageService _faceStorageService = FaceStorageService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _familyMembers = [];
  String _currentUserRole = 'member';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFamilyMembers();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserRole = data['role'] ?? 'member';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _familyMembers = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'role': data['role'] ?? 'member',
            'imageUrl': data['latestFaceUrl'] ?? '',
            'imageCount': data['imageCount'] ?? 0,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading family members: $e');
      setState(() => _isLoading = false);
    }
  }

  bool get isHomeowner => _currentUserRole == 'homeowner';

  void _addFamilyMember() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Family Member'),
        content: const Text('Use the Face Detection page to capture and add new family members.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FaceDetectionPage()),
              ).then((_) {
                // Refresh after returning from FaceDetectionPage
                _loadFamilyMembers();
              });
            },
            child: const Text('Go to Face Detection'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFamilyMember(String memberId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Family Member'),
        content: Text('Are you sure you want to remove $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _faceStorageService.deleteFamilyMember(memberId);
        await _loadFamilyMembers(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors from your design system
    final Color primaryColor = const Color(0xFF2D3748);
    final Color secondaryColor = const Color(0xFF4A5568);
    final Color accentColor = const Color(0xFF4299E1);
    final Color backgroundColor = const Color(0xFFF7FAFC);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Family Members",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3748)),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: backgroundColor,
            child: Row(
              children: [
                Icon(
                  isHomeowner ? Icons.admin_panel_settings : Icons.visibility,
                  color: accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isHomeowner
                        ? 'You can add or remove family members'
                        : 'View only - Contact homeowner to make changes',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Family members grid
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : _familyMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No family members yet',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (isHomeowner)
                              TextButton(
                                onPressed: _addFamilyMember,
                                child: const Text('Add First Member'),
                              ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _familyMembers.length,
                        itemBuilder: (context, index) {
                          final member = _familyMembers[index];
                          return _buildFamilyMemberCard(member);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isHomeowner
          ? FloatingActionButton.extended(
              onPressed: _addFamilyMember,
              backgroundColor: accentColor,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Member'),
            )
          : null,
    );
  }

  Widget _buildFamilyMemberCard(Map<String, dynamic> member) {
    final Color primaryColor = const Color(0xFF2D3748);
    final Color accentColor = const Color(0xFF4299E1);
    final Color homeownerColor = Colors.orange;
    final Color memberColor = Colors.blue;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Profile image
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    image: member['imageUrl'] != null && member['imageUrl'].isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(member['imageUrl']),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey.shade200,
                  ),
                  child: member['imageUrl'] == null || member['imageUrl'].isEmpty
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),

                // Role badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: member['role'] == 'homeowner'
                          ? homeownerColor.withOpacity(0.2)
                          : memberColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      member['role'] == 'homeowner' ? 'Owner' : 'Member',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: member['role'] == 'homeowner'
                            ? homeownerColor
                            : memberColor,
                      ),
                    ),
                  ),
                ),

                // Image count badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${member['imageCount']} img',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Delete button (only for homeowners and non-homeowner members)
                if (isHomeowner && member['role'] != 'homeowner')
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () => _removeFamilyMember(member['id'], member['name']),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Name
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  member['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${member['imageCount']} face image(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}