import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:app12/services/face_storage_service.dart';
import 'package:app12/services/pi_face_service.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  String _detectionStatus = 'Initializing camera...';
  List<Map<String, dynamic>> _recognizedFaces = [];
  bool _showCamera = true;
  bool _isPiConnected = false;

  // Services
  late FaceStorageService _faceStorageService;
  late PiFaceService _piFaceService;

  // Colors
  final Color primaryColor = const Color(0xFF2D3748);
  final Color secondaryColor = const Color(0xFF4A5568);
  final Color accentColor = const Color(0xFF4299E1);
  final Color backgroundColor = const Color(0xFFF7FAFC);
  final Color surfaceColor = Colors.white;
  final Color successColor = const Color(0xFF48BB78);
  final Color errorColor = const Color(0xFFF56565);
  final Color warningColor = const Color(0xFFED8936);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController == null) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeServices() async {
    _faceStorageService = FaceStorageService();
    _piFaceService = PiFaceService();
    
    // Test Raspberry Pi connection
    try {
      _isPiConnected = await _piFaceService.testConnection();
      if (_isPiConnected) {
        setState(() {
          _detectionStatus = 'Pi connected. Initializing camera...';
        });
      } else {
        setState(() {
          _detectionStatus = 'Pi not connected. Using local mode...';
        });
      }
    } catch (e) {
      setState(() {
        _detectionStatus = 'Pi connection test failed: $e';
      });
    }
    
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _detectionStatus = 'No camera available';
        });
        return;
      }

      // Use back camera
      final CameraDescription camera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      setState(() {
        _isCameraInitialized = true;
        _detectionStatus = _isPiConnected 
            ? 'Ready - Pi connected' 
            : 'Ready - Local mode';
      });
    } catch (e) {
      setState(() {
        _detectionStatus = 'Camera error: ${e.toString()}';
      });
    }
  }

  Future<void> _captureAndRegisterFace() async {
    if (!_isCameraInitialized || _cameraController == null) {
      _showError('Camera not ready');
      return;
    }

    try {
      setState(() {
        _detectionStatus = 'Capturing image...';
      });

      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      final File file = File(imageFile.path);

      // Show dialog to select family member
      final familyMembers = await _getFamilyMembers();
      
      if (familyMembers.isEmpty) {
        _showAddMemberDialog(file);
      } else {
        _showMemberSelectionDialog(familyMembers, file);
      }

      setState(() {
        _detectionStatus = _isPiConnected 
            ? 'Ready - Pi connected' 
            : 'Ready - Local mode';
      });
    } catch (e) {
      _showError('Capture error: $e');
      setState(() {
        _detectionStatus = 'Error during capture';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getFamilyMembers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('family_members')
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'role': data['role'] ?? 'member',
          'imageUrl': data['latestFaceUrl'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  void _showAddMemberDialog(File imageFile) {
    showDialog(
      context: context,
      builder: (context) => AddMemberDialog(
        imageFile: imageFile,
        onAdd: (name, role) async {
          try {
            // Show loading
            _showLoading('Adding family member...');
            
            // Add to Firebase
            await _faceStorageService.addFamilyMember(
              name: name,
              role: role,
              faceImage: imageFile,
            );
            
            // Register with Raspberry Pi
            if (_isPiConnected) {
              final success = await _piFaceService.registerFamilyMemberFace(imageFile, name, role);
              if (!success) {
                _showWarning('Added to app but failed to register with Pi');
              }
            }
            
            // Hide loading
            Navigator.pop(context);
            
            _showSuccess('$name added successfully');
            
            // Refresh the page
            setState(() {});
          } catch (e) {
            Navigator.pop(context); // Hide loading
            _showError('Error: $e');
          }
        },
      ),
    );
  }

  void _showMemberSelectionDialog(List<Map<String, dynamic>> members, File imageFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Family Member'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: members.isEmpty
              ? const Center(child: Text('No family members found'))
              : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: member['imageUrl'] != null
                            ? NetworkImage(member['imageUrl']!)
                            : null,
                        child: member['imageUrl'] == null 
                            ? const Icon(Icons.person) 
                            : null,
                      ),
                      title: Text(member['name']),
                      subtitle: Text(member['role']),
                      onTap: () async {
                        Navigator.pop(context);
                        await _updateMemberFace(member['id'], imageFile, member['name']);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddMemberDialog(imageFile);
            },
            child: const Text('Add New Member'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMemberFace(String memberId, File imageFile, String memberName) async {
    try {
      _showLoading('Updating face...');
      
      // Update in Firebase
      await _faceStorageService.updateFamilyMemberFace(
        memberId: memberId,
        newFaceImage: imageFile,
      );
      
      // Update in Raspberry Pi
      if (_isPiConnected) {
        final success = await _piFaceService.registerFamilyMemberFace(imageFile, memberName, 'member');
        if (!success) {
          _showWarning('Updated in app but failed to update in Pi');
        }
      }
      
      Navigator.pop(context); // Hide loading
      _showSuccess('Face updated for $memberName');
      
    } catch (e) {
      Navigator.pop(context); // Hide loading
      _showError('Update error: $e');
    }
  }

  Future<void> _testFaceDetection() async {
    if (!_isCameraInitialized || _cameraController == null) {
      _showError('Camera not ready');
      return;
    }

    try {
      setState(() {
        _isDetecting = true;
        _detectionStatus = 'Detecting face...';
      });

      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      final File file = File(imageFile.path);

      // Send to Raspberry Pi for recognition
      final result = await _piFaceService.recognizeFace(file);
      
      if (result['success'] == true) {
        final person = result['person'] ?? 'Unknown';
        final confidence = result['confidence'] ?? 0.0;
        final type = result['type'] ?? 'stranger';
        final imageUrl = result['imageUrl'] ?? '';
        
        setState(() {
          _detectionStatus = 'Detected: $person (${(confidence * 100).toStringAsFixed(1)}%)';
          
          // Add to recognized faces list
          _recognizedFaces.insert(0, {
            'person': person,
            'confidence': confidence,
            'type': type,
            'time': DateTime.now(),
            'imageUrl': imageUrl,
          });
          
          // Keep only last 10 entries
          if (_recognizedFaces.length > 10) {
            _recognizedFaces.removeLast();
          }
        });
        
        // Show notification
        _showDetectionNotification(person, type, confidence);
      } else {
        setState(() {
          _detectionStatus = 'No face detected';
        });
        _showError(result['error'] ?? 'Detection failed');
      }
    } catch (e) {
      setState(() {
        _detectionStatus = 'Detection error';
      });
      _showError('Detection error: $e');
    } finally {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  void _showDetectionNotification(String person, String type, double confidence) {
    final color = type == 'stranger' ? errorColor : successColor;
    final icon = type == 'stranger' ? Icons.warning : Icons.verified_user;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type == 'stranger' 
                  ? '🚨 Stranger detected!' 
                  : '✅ $person recognized (${(confidence * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: warningColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: accentColor),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        title: const Text('Face Detection CCTV'),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          // Pi connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  _isPiConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isPiConnected ? successColor : errorColor,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _isPiConnected ? 'Pi' : 'Offline',
                  style: TextStyle(
                    color: _isPiConnected ? successColor : errorColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _captureAndRegisterFace,
            tooltip: 'Capture & Register Face',
          ),
          IconButton(
            icon: Icon(_showCamera ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showCamera = !_showCamera;
              });
            },
            tooltip: _showCamera ? 'Hide Camera' : 'Show Camera',
          ),
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: _testFaceDetection,
            tooltip: 'Test Face Detection',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Preview or Status
          if (_showCamera && _isCameraInitialized)
            Expanded(
              child: Stack(
                children: [
                  CameraPreview(_cameraController!),
                  
                  // Detection status overlay
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isDetecting 
                                  ? Colors.amber 
                                  : (_isPiConnected ? Colors.green : Colors.red),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _detectionStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Capture button overlay
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton(
                        onPressed: _captureAndRegisterFace,
                        backgroundColor: accentColor,
                        child: const Icon(Icons.camera, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!_showCamera)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.videocam_off,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Hidden',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap eye icon to show camera',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: accentColor),
                    const SizedBox(height: 16),
                    Text(
                      _detectionStatus,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    if (!_isPiConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Raspberry Pi not connected',
                          style: TextStyle(
                            color: warningColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // Recognition History
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Recent Detections',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const Spacer(),
                    if (_recognizedFaces.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _recognizedFaces.clear();
                          });
                        },
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _recognizedFaces.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.face,
                                size: 48,
                                color: secondaryColor.withOpacity(0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No detections yet',
                                style: TextStyle(color: secondaryColor),
                              ),
                              Text(
                                'Tap the security icon to test',
                                style: TextStyle(
                                  color: secondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _recognizedFaces.length,
                          itemBuilder: (context, index) {
                            final detection = _recognizedFaces[index];
                            final isStranger = detection['type'] == 'stranger';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isStranger
                                      ? errorColor.withOpacity(0.3)
                                      : successColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isStranger
                                          ? errorColor.withOpacity(0.1)
                                          : successColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isStranger
                                          ? Icons.warning
                                          : Icons.verified_user,
                                      color: isStranger
                                          ? errorColor
                                          : successColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          detection['person'] == 'Unknown'
                                              ? 'Stranger Detected'
                                              : detection['person'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: primaryColor,
                                          ),
                                        ),
                                        Text(
                                          '${(detection['confidence'] * 100).toStringAsFixed(1)}% • ${_formatTime(detection['time'])}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (detection['imageUrl'] != null && detection['imageUrl'].isNotEmpty)
                                    IconButton(
                                      icon: Icon(
                                        Icons.image,
                                        color: accentColor,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        // Show image dialog
                                        _showImageDialog(detection['imageUrl']);
                                      },
                                      tooltip: 'View image',
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(imageUrl),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

// Dialog for adding new member
class AddMemberDialog extends StatefulWidget {
  final File imageFile;
  final Function(String name, String role) onAdd;

  const AddMemberDialog({
    super.key,
    required this.imageFile,
    required this.onAdd,
  });

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _nameController = TextEditingController();
  String _selectedRole = 'member';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Family Member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image preview
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(widget.imageFile),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                hintText: 'Enter family member name',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Role:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile(
                    title: const Text('Homeowner'),
                    value: 'homeowner',
                    groupValue: _selectedRole,
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    title: const Text('Member'),
                    value: 'member',
                    groupValue: _selectedRole,
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a name'),
                  backgroundColor: Colors.red,
                ),
              );
            } else {
              widget.onAdd(name, _selectedRole);
              Navigator.pop(context);
            }
          },
          child: const Text('Add Member'),
        ),
      ],
    );
  }
}