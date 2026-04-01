import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class OcrService {
  static final RegExp _cvuPattern = RegExp(r'\b\d{22}\b');

  String? _tempPath;
  String? _apiKeyValue;
  double screenWidth = 0;
  double screenHeight = 0;
  bool _isProcessing = false;

  Future<void> init(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) return;
    _apiKeyValue = apiKey;
  }

  Future<String?> detectAlias(CameraImage image, CameraDescription camera) async {
    if (_isProcessing || _apiKeyValue == null || image.planes.isEmpty) return null;
    _isProcessing = true;

    try {
      final jpegBytes = await compute(_toJpeg, {
        'yBytes': image.planes[0].bytes,
        'uBytes': image.planes[1].bytes,
        'vBytes': image.planes[2].bytes,
        'width': image.width,
        'height': image.height,
        'yRowStride': image.planes[0].bytesPerRow,
        'uvRowStride': image.planes[1].bytesPerRow,
        'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
        'rotation': camera.sensorOrientation,
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
      });

      if (jpegBytes == null) { _isProcessing = false; return null; }

      _tempPath ??= '${(await getTemporaryDirectory()).path}/ocr_frame.jpg';
      await File(_tempPath!).writeAsBytes(jpegBytes);

      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_apiKeyValue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [{
            'image': {'content': base64Encode(jpegBytes)},
            'features': [{'type': 'TEXT_DETECTION', 'maxResults': 5}],
          }]
        }),
      );

      _isProcessing = false;
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final rawText = json['responses']?[0]?['fullTextAnnotation']?['text']?.toString() ?? '';
      if (rawText.isEmpty) return null;

      if (_cvuPattern.hasMatch(rawText)) return _cvuPattern.firstMatch(rawText)!.group(0);

      // --- THE "FORCE DOT" LOGIC ---

      // 1. Convert to lower and strip the "Alias" label from the start
      String text = rawText.toLowerCase().replaceAll('\n', ' ').trim();
      text = text.replaceFirst(RegExp(r'^alias\s*[:=]?\s*'), '');

      // 2. OCR FIX: Replace commas, dashes, or semicolons with dots
      // These are the most common "hallucinations" for a real dot
      text = text.replaceAll(RegExp(r'[,\-;_]'), '.');

      // 3. JOINING LOGIC:
      String finalResult;
      if (text.contains('.')) {
        // If dots exist, remove ALL spaces to glue "pipa . lean" into "pipa.lean"
        finalResult = text.replaceAll(' ', '');
      } else {
        // If no dots found, just join the words into one (arielbarberis)
        finalResult = text.replaceAll(' ', '');
      }

      // 4. Final Clean: Only alphanumeric and the dots we preserved/forced
      finalResult = finalResult.replaceAll(RegExp(r'[^a-z0-9\.]'), '');
      
      // 5. Clean trailing/leading garbage
      final cleanResult = finalResult.replaceAll(RegExp(r'^\.+|\.+$'), '');

      if (cleanResult.length >= 6) {
        debugPrint('CLEAN CAPTURE: $cleanResult');
        return cleanResult;
      }
      
      return null;
    } catch (e) { _isProcessing = false; return null; }
  }

  static Uint8List? _toJpeg(Map<String, dynamic> data) {
    try {
      final Uint8List yBytes = data['yBytes'] as Uint8List;
      final Uint8List uBytes = data['uBytes'] as Uint8List;
      final Uint8List vBytes = data['vBytes'] as Uint8List;
      final int width = data['width'] as int;
      final int height = data['height'] as int;
      final int yRowStride = data['yRowStride'] as int;
      final int uvRowStride = data['uvRowStride'] as int;
      final int uvPixelStride = data['uvPixelStride'] as int;
      final int sensorOrientation = data['rotation'] as int;
      final double sWidth = (data['screenWidth'] as double?) ?? 0;
      final double sHeight = (data['screenHeight'] as double?) ?? 0;

      final rgbImage = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIdx = y * yRowStride + x;
          final int uvRow = (y >> 1) * uvRowStride;
          final int uvCol = (x >> 1) * uvPixelStride;
          final int uvIdx = uvRow + uvCol;
          if (yIdx >= yBytes.length) continue;
          final int yVal = yBytes[yIdx] & 0xFF;
          final int uVal = uvIdx < uBytes.length ? (uBytes[uvIdx] & 0xFF) : 128;
          final int vVal = uvIdx < vBytes.length ? (vBytes[uvIdx] & 0xFF) : 128;
          final int c = yVal - 16, d = uVal - 128, e = vVal - 128;
          final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
          final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
          final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
          rgbImage.setPixelRgb(x, y, r, g, b);
        }
      }

      img.Image rotated;
      switch (sensorOrientation) {
        case 90:  rotated = img.copyRotate(rgbImage, angle: 90); break;
        case 180: rotated = img.copyRotate(rgbImage, angle: 180); break;
        case 270: rotated = img.copyRotate(rgbImage, angle: 270); break;
        default:  rotated = rgbImage;
      }

      if (sWidth > 0 && sHeight > 0) {
        final double scaleX = rotated.width / sWidth;
        final double scaleY = rotated.height / sHeight;
        final int cropX = ((sWidth * 0.1) * scaleX).round();
        final int cropY = ((sHeight * 0.35) * scaleY).round();
        final int cropW = ((sWidth * 0.8) * scaleX).round();
        final int cropH = (220.0 * scaleY).round();
        final cropped = img.copyCrop(rotated, x: cropX, y: cropY, width: cropW, height: cropH);
        return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
      }
      return Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
    } catch (e) { return null; }
  }

  void dispose() {}
}
