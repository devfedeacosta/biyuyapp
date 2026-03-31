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
  bool _isInitializing = false;

  double screenWidth = 0;
  double screenHeight = 0;

  Future<void> init(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('OCR ERROR: API Key is empty. Check .env');
      return;
    }
    _isInitializing = true;
    _apiKeyValue = apiKey;
    _isInitializing = false;
    debugPrint('OCR Service: Initialized.');
  }

  Future<String?> detectAlias(
      CameraImage image, CameraDescription camera) async {
    try {
      if (_apiKeyValue == null || _apiKeyValue!.isEmpty || _isInitializing) {
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

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final rawText = json['responses']?[0]?['fullTextAnnotation']?['text']
              ?.toString() ?? '';

      if (rawText.isEmpty) return null;

      // 1. CVU Priority
      final cvuMatch = _cvuPattern.firstMatch(rawText);
      if (cvuMatch != null) return cvuMatch.group(0);

      // 2. PRIORITY: Clean Single Word & Artifact Removal
      // This catches custom aliases even if OCR adds a fake dot/comma
      final potentialChunks = rawText.split(RegExp(r'[\s\n,:]+'));
      for (final chunk in potentialChunks) {
        // Remove trailing/leading symbols
        final rawWord = chunk.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '');
        
        // Strategy A: Direct Check (No dots)
        if (rawWord.length >= 6 && !rawWord.contains('.')) {
          if (_isLikelyAlias(rawWord)) {
            debugPrint('OCR SINGLE WORD: "$rawWord"');
            return rawWord.toLowerCase();
          }
        }

        // Strategy B: Artifact Removal (Ignore dots inside long strings)
        if (rawWord.contains('.')) {
          final stripped = rawWord.replaceAll('.', '');
          if (stripped.length >= 7 && _isLikelyAlias(stripped)) {
            debugPrint('OCR STRIPPED ARTIFACTS: "$stripped"');
            return stripped.toLowerCase();
          }
        }
      }

      // 3. FALLBACK: Dot-Separated Logic (For casa.perro.luz)
      final cleaned = rawText
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'[,،]'), '.') 
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final r1 = _extractAlias(cleaned);
      if (r1 != null) return r1;

      final r2 = _extractAlias(cleaned.replaceAll(RegExp(r'\s*\.\s*'), '.'));
      if (r2 != null) return r2;

      return null;
    } catch (e) {
      debugPrint('OCR ERROR: $e');
      return null;
    }
  }

  String? _extractAlias(String text) {
    for (final match in _aliasPattern.allMatches(text)) {
      final candidate = match.group(0)!.toLowerCase().trim();
      if (_isLikelyAlias(candidate)) return candidate;
    }
    return null;
  }

  static const List<String> _argSuffixes = [
    '.mp', '.pp', '.modo', '.bna', '.bbva', '.galicia',
    '.santander', '.macro', '.naranja', '.uala', '.brubank',
    '.personal', '.claro', '.telecom', '.hsbc', '.icbc',
    '.supervielle', '.patagonia', '.comafi', '.bind', '.mercadopago'
  ];

  static const Set<String> _forbidden = {
    'alias', 'cbu', 'cvu', 'pago', 'monto', 'enviar', 'alias:', 'nombre', 'titular', 'aceptar', 'destino'
  };

  bool _isLikelyAlias(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (_forbidden.contains(lower)) return false;

    if (_argSuffixes.any((s) => lower.endsWith(s)) && text.length >= 4) return true;
    if (text.contains('@') || text.startsWith('www.') || text.contains('://')) return false;

    final segments = text.split('.');
    if (segments.length == 1) {
      if (text.length < 6) return false; 
      final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(text);
      final isAlphanumeric = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
      return hasLetters && isAlphanumeric && !RegExp(r'^\d+$').hasMatch(text);
    }
    return segments.length <= 4 && text.length >= 5;
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
        final double boxWidthRatio = 0.8;
        const double boxHeight = 220.0;
        final double boxTopRatio = 0.35;
        final double scaleX = rotated.width / sWidth;
        final double scaleY = rotated.height / sHeight;
        final int cropX = ((sWidth * (1 - boxWidthRatio) / 2) * scaleX).round();
        final int cropY = ((sHeight * boxTopRatio) * scaleY).round();
        final int cropW = ((sWidth * boxWidthRatio) * scaleX).round();
        final int cropH = (boxHeight * scaleY).round();
        final int padX = (cropW * 0.05).round();
        final int padY = (cropH * 0.1).round();
        final int finalX = (cropX - padX).clamp(0, rotated.width - 1);
        final int finalY = (cropY - padY).clamp(0, rotated.height - 1);
        final int finalW = (cropW + padX * 2).clamp(1, rotated.width - finalX);
        final int finalH = (cropH + padY * 2).clamp(1, rotated.height - finalY);

        final cropped = img.copyCrop(rotated, x: finalX, y: finalY, width: finalW, height: finalH);
        return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
      }
      return Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
    } catch (e) {
      return null;
    }
  }

  void dispose() {}
}