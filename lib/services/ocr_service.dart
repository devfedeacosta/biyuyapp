import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class OcrService {
  static final RegExp _aliasPattern = RegExp(
    r'\b([a-zA-Z0-9]+\.){1,3}[a-zA-Z0-9]+\b',
    caseSensitive: false,
  );
  static final RegExp _cvuPattern = RegExp(r'\b\d{22}\b');

  String? _tempPath;
  String? _apiKeyValue;

  // Scan box ratio — must match scanner_overlay.dart
  // boxWidth = screenWidth * 0.8, boxHeight = 220, boxTop = screenHeight * 0.35
  // We pass screen dimensions from the UI
  double screenWidth = 0;
  double screenHeight = 0;

  Future<void> init(String apiKey) async {
    _apiKeyValue = apiKey;
  }

  Future<String?> detectAlias(
      CameraImage image, CameraDescription camera) async {
    try {
      if (_apiKeyValue == null || _apiKeyValue!.isEmpty) {
        debugPrint('OCR: no API key set');
        return null;
      }

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
        // Pass screen dimensions for crop
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
      });

      if (jpegBytes == null) return null;

      _tempPath ??= '${(await getTemporaryDirectory()).path}/ocr_frame.jpg';
      await File(_tempPath!).writeAsBytes(jpegBytes);

      final base64Image = base64Encode(jpegBytes);
      final response = await http.post(
        Uri.parse(
            'https://vision.googleapis.com/v1/images:annotate?key=$_apiKeyValue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'TEXT_DETECTION', 'maxResults': 5},
              ],
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('OCR API error: ${response.statusCode} ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body);
      final rawText = json['responses']?[0]?['fullTextAnnotation']?['text']
              ?.toString() ?? '';

      debugPrint('OCR TEXT: "$rawText"');
      if (rawText.isEmpty) return null;

      // CVU check
      final cvuMatch = _cvuPattern.firstMatch(rawText);
      if (cvuMatch != null) return cvuMatch.group(0);

      final cleaned = rawText
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'[,،]'), '.')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Strategy 1: direct match
      final r1 = _extractAlias(cleaned);
      if (r1 != null) return r1;

      // Strategy 2: spaces around dots
      final r2 = _extractAlias(cleaned.replaceAll(RegExp(r'\s*\.\s*'), '.'));
      if (r2 != null) return r2;

      // Strategy 3: no spaces
      final r3 = _extractAlias(cleaned.replaceAll(' ', ''));
      if (r3 != null) return r3;

      // Strategy 4: word reconstruction
      final words = cleaned
          .toLowerCase()
          .split(' ')
          .map((w) => w.replaceAll(RegExp(r'[^a-z0-9.]'), ''))
          .where((w) => w.isNotEmpty && RegExp(r'^[a-z0-9.]+$').hasMatch(w))
          .toList();

      debugPrint('OCR WORDS: $words');

      if (words.length >= 2 && words.length <= 5) {
        // Try: (all but last joined) . (last)
        final prefix = words.sublist(0, words.length - 1).join('');
        final suffix = words.last;
        final c1 = '$prefix.$suffix';
        debugPrint('OCR TRY: "$c1"');
        if (_isLikelyAlias(c1)) return c1;

        // Try: (first) . (rest joined)
        final c2 = '${words.first}.${words.sublist(1).join('')}';
        debugPrint('OCR TRY: "$c2"');
        if (_isLikelyAlias(c2)) return c2;

        // Try all with dots
        final c3 = words.join('.');
        debugPrint('OCR TRY: "$c3"');
        if (_isLikelyAlias(c3)) return c3;
      }

      return null;
    } catch (e) {
      debugPrint('OCR ERROR: $e');
      return null;
    }
  }

  String? _extractAlias(String text) {
    for (final match in _aliasPattern.allMatches(text)) {
      final candidate = match.group(0)!.toLowerCase().trim();
      debugPrint('OCR CANDIDATE: "$candidate"');
      if (_isLikelyAlias(candidate)) return candidate;
    }
    return null;
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
      final double screenWidth = (data['screenWidth'] as double?) ?? 0;
      final double screenHeight = (data['screenHeight'] as double?) ?? 0;

      // Build full RGB image
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

      // Rotate
      img.Image rotated;
      switch (sensorOrientation) {
        case 90:  rotated = img.copyRotate(rgbImage, angle: 90); break;
        case 180: rotated = img.copyRotate(rgbImage, angle: 180); break;
        case 270: rotated = img.copyRotate(rgbImage, angle: 270); break;
        default:  rotated = rgbImage;
      }

      // Crop to scan box area if screen dimensions are available
      if (screenWidth > 0 && screenHeight > 0) {
        final double boxWidthRatio = 0.8;
        const double boxHeight = 220.0;
        final double boxTopRatio = 0.35;

        final double scaleX = rotated.width / screenWidth;
        final double scaleY = rotated.height / screenHeight;

        final int cropX = ((screenWidth * (1 - boxWidthRatio) / 2) * scaleX).round();
        final int cropY = ((screenHeight * boxTopRatio) * scaleY).round();
        final int cropW = ((screenWidth * boxWidthRatio) * scaleX).round();
        final int cropH = (boxHeight * scaleY).round();

        // Add padding around the box
        final int padX = (cropW * 0.05).round();
        final int padY = (cropH * 0.1).round();

        final int finalX = (cropX - padX).clamp(0, rotated.width - 1);
        final int finalY = (cropY - padY).clamp(0, rotated.height - 1);
        final int finalW = (cropW + padX * 2).clamp(1, rotated.width - finalX);
        final int finalH = (cropH + padY * 2).clamp(1, rotated.height - finalY);

        debugPrint('OCR CROP: ${finalX},${finalY} ${finalW}x${finalH} from ${rotated.width}x${rotated.height}');

        final cropped = img.copyCrop(rotated,
            x: finalX, y: finalY, width: finalW, height: finalH);
        return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
      }

      return Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
    } catch (e) {
      return null;
    }
  }

  // Known Argentine payment app suffixes
  static const List<String> _argSuffixes = [
    '.mp', '.pp', '.modo', '.bna', '.bbva', '.galicia',
    '.santander', '.macro', '.naranja', '.uala', '.brubank',
    '.personal', '.claro', '.telecom', '.hsbc', '.icbc',
    '.supervielle', '.patagonia', '.comafi', '.bind',
  ];

  bool _isLikelyAlias(String text) {
    final lower = text.toLowerCase();
    // Accept directly if ends with known Argentine suffix
    if (_argSuffixes.any((s) => lower.endsWith(s)) && text.length >= 5) return true;
    // Known Argentine payment suffixes
    final knownSuffixes = ['.mp', '.pp', '.modo', '.bna', '.bbva', '.galicia', '.santander', '.macro', '.naranja', '.uala', '.brubank', '.mercadopago'];
    final lowerText = text.toLowerCase();
    final hasKnownSuffix = knownSuffixes.any((s) => lowerText.endsWith(s));
    // If it has a known suffix, accept it directly
    if (hasKnownSuffix && text.length >= 5) return true;
    if (text.isEmpty) return false;
    if (text.contains('@')) return false;
    if (text.startsWith('www.')) return false;
    if (text.contains('://')) return false;
    if (text.endsWith('.com') || text.endsWith('.ar') || text.endsWith('.org')) return false;
    final segments = text.split('.');
    if (segments.length < 2) return false;
    if (segments.length > 4) return false;
    if (segments.any((s) => s.isEmpty)) return false;
    // Allow short segments like .mp .pp
    if (segments.any((s) => s.length < 1)) return false;
    if (segments.every((s) => RegExp(r'^\d+$').hasMatch(s))) return false;
    if (!segments.any((s) => RegExp(r'[a-zA-Z]').hasMatch(s))) return false;
    if (text.length < 5) return false;
    return true;
  }

  void dispose() {}
}
