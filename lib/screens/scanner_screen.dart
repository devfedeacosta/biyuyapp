import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ocr_service.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/alias_result_sheet.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final OcrService _ocrService = OcrService();

  bool _isProcessing = false;
  bool _cameraReady = false;
  bool _aliasFound = false;
  String? _detectedAlias;
  String _statusMessage = 'Apuntá la cámara al alias de MercadoPago';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _statusMessage = 'Se necesita permiso de cámara');
      return;
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      setState(() => _statusMessage = 'No se encontró cámara');
      return;
    }

    _controller = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      _startImageStream();
    } catch (e) {
      setState(() => _statusMessage = 'Error al iniciar cámara: $e');
    }
  }

  void _startImageStream() {
    _controller?.startImageStream((CameraImage image) async {
      if (_isProcessing || _aliasFound) return;
      _isProcessing = true;

      final alias = await _ocrService.detectAlias(image, _cameras.first);

      if (alias != null && mounted) {
        setState(() {
          _aliasFound = true;
          _detectedAlias = alias;
        });
        await _controller?.stopImageStream();
        _onAliasDetected(alias);
      }

      _isProcessing = false;
    });
  }

  void _onAliasDetected(String alias) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AliasResultSheet(
        alias: alias,
        onScanAgain: _resetScanner,
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _aliasFound = false;
      _detectedAlias = null;
      _statusMessage = 'Apuntá la cámara al alias de MercadoPago';
    });
    _startImageStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_cameraReady && _controller != null)
            Positioned.fill(
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF009EE3)),
            ),
          if (_cameraReady)
            ScannerOverlay(
              statusMessage: _statusMessage,
              aliasDetected: _aliasFound,
              detectedAlias: _detectedAlias,
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF009EE3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Biyuy',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
