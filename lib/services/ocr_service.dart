import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static final RegExp _aliasPattern = RegExp(
    r'\b([a-zA-Z0-9]+\.){1,3}[a-zA-Z0-9]+\b',
    caseSensitive: false,
  );

  static final RegExp _cvuPattern = RegExp(r'\b\d{22}\b');

  Future<String?> detectAlias(CameraImage image, CameraDescription camera) async {
    try {
      final inputImage = _buildInputImage(image, camera);
      if (inputImage == null) return null;

      final recognized = await _recognizer.processImage(inputImage);
      final fullText = recognized.text;

      if (fullText.isEmpty) return null;

      final cvuMatch = _cvuPattern.firstMatch(fullText);
      if (cvuMatch != null) return cvuMatch.group(0);

      for (final match in _aliasPattern.allMatches(fullText)) {
        final candidate = match.group(0)!.toLowerCase().trim();
        if (_isLikelyAlias(candidate)) return candidate;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isLikelyAlias(String text) {
    if (text.contains('@')) return false;
    if (text.startsWith('www.')) return false;
    if (text.contains('://')) return false;
    if (text.endsWith('.com') || text.endsWith('.ar') || text.endsWith('.org')) return false;
    if (text.split('.').length > 4) return false;

    final segments = text.split('.');
    final allNumeric = segments.every((s) => RegExp(r'^\d+$').hasMatch(s));
    if (allNumeric) return false;

    final hasAlpha = segments.any((s) => RegExp(r'[a-zA-Z]').hasMatch(s));
    if (!hasAlpha) return false;

    if (text.length < 5) return false;

    return true;
  }

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final rotation = _getRotation(camera.sensorOrientation);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation _getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default: return InputImageRotation.rotation0deg;
    }
  }

  void dispose() {
    _recognizer.close();
  }
}
