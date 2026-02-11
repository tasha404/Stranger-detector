// services/camera_service.dart
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  StreamController<Uint8List> _frameStreamController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get frameStream => _frameStreamController.stream;

  Future<void> initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use back camera by default
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      _isInitialized = true;
      
      // Start image stream
      await startImageStream();

    } catch (e) {
      print('Camera initialization error: $e');
      rethrow;
    }
  }

  Future<void> startImageStream() async {
    if (!_isInitialized || _cameraController == null) return;

    await _cameraController!.startImageStream((CameraImage image) async {
      try {
        // Convert YUV420 to JPEG
        final jpegBytes = await _convertYUV420toJPEG(image);
        _frameStreamController.add(jpegBytes);
      } catch (e) {
        print('Image processing error: $e');
      }
    });
  }

  Future<Uint8List> _convertYUV420toJPEG(CameraImage image) async {
    try {
      final img.Image yuvImage = img.Image(
        width: image.width,
        height: image.height,
      );

      // Convert YUV to RGB (simplified)
      // Note: For production, use a proper YUV to RGB conversion
      final planeY = image.planes[0];
      final planeU = image.planes[1];
      final planeV = image.planes[2];

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final yIndex = y * planeY.bytesPerRow + x;
          final uvIndex = (y ~/ 2) * planeU.bytesPerRow + (x ~/ 2) * 2;

          final yValue = planeY.bytes[yIndex];
          final uValue = planeU.bytes[uvIndex];
          final vValue = planeV.bytes[uvIndex + 1];

          // Convert YUV to RGB
          final r = yValue + 1.402 * (vValue - 128);
          final g = yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
          final b = yValue + 1.772 * (uValue - 128);

          yuvImage.setPixelRgb(
            x,
            y,
            r.clamp(0, 255).toInt(),
            g.clamp(0, 255).toInt(),
            b.clamp(0, 255).toInt(),
          );
        }
      }

      // Convert to JPEG
      final jpegBytes = img.encodeJpg(yuvImage, quality: 85);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      print('YUV conversion error: $e');
      // Return a placeholder if conversion fails
      return Uint8List(0);
    }
  }

  Future<File> captureImage() async {
    if (!_isInitialized || _cameraController == null) {
      throw Exception('Camera not initialized');
    }

    try {
      final xFile = await _cameraController!.takePicture();
      return File(xFile.path);
    } catch (e) {
      print('Capture image error: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
    await _frameStreamController.close();
  }

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
}