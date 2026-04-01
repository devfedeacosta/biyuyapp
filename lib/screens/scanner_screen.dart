import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ocr_service.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/alias_result_sheet.dart';

class ScannerScreen extends StatefulWidget {
  final OcrService ocrService;
  const ScannerScreen({super.key, required this.ocrService});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  bool _cameraReady = false;
  bool _aliasFound = false;
  bool _isScanning = false;
  String? _detectedAlias;
  String _statusMessage = 'Apuntá al alias y presioná Escanear';

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
    widget.ocrService.dispose();
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
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (e) {
      setState(() => _statusMessage = 'Error al iniciar cámara: $e');
    }
  }

  Future<void> _triggerScan() async {
    if (_isScanning || !_cameraReady) return;
    setState(() {
      _isScanning = true;
      _statusMessage = 'Escaneando...';
    });
    HapticFeedback.mediumImpact();

    try {
      CameraImage? captured;
      final completer = _SimpleCompleter<CameraImage>();
      await _controller!.startImageStream((image) async {
        if (!completer.isCompleted) {
          completer.complete(image);
          await _controller!.stopImageStream();
        }
      });
      captured = await completer.future;

      final size = MediaQuery.of(context).size;
      widget.ocrService.screenWidth = size.width;
      widget.ocrService.screenHeight = size.height;

      final alias = await widget.ocrService.detectAlias(captured, _cameras.first);

      if (!mounted) return;
      if (alias != null) {
        setState(() {
          _aliasFound = true;
          _detectedAlias = alias;
          _isScanning = false;
        });
        HapticFeedback.heavyImpact();
        _onAliasDetected(alias);
      } else {
        setState(() {
          _isScanning = false;
          _statusMessage = 'No se detectó alias. Intentá de nuevo.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Error al escanear. Intentá de nuevo.';
        });
      }
    }
  }

  void _onAliasDetected(String alias) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
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
      _isScanning = false;
      _statusMessage = 'Apuntá al alias y presioná Escanear';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_cameraReady && _controller != null)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),

          if (_cameraReady)
            ScannerOverlay(
              statusMessage: _statusMessage,
              aliasDetected: _aliasFound,
              detectedAlias: _detectedAlias,
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
                    ),
                    child: Stack(
                      children: [
                        Text(
                          'Biyuyapp',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 4
                              ..color = const Color(0xFF033728),
                          ),
                        ),
                        const Text(
                          'Biyuyapp',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFF6EE7B7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scan button
          if (_cameraReady && !_aliasFound)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _isScanning ? null : _triggerScan,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isScanning ? 72 : 82,
                      height: _isScanning ? 72 : 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isScanning
                            ? const Color(0xFF10B981).withOpacity(0.6)
                            : const Color(0xFF10B981),
                        border: Border.all(color: const Color(0xFF064E3B), width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isScanning
                          ? const Padding(
                              padding: EdgeInsets.all(22),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(
                              Icons.document_scanner_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escanear',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
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

class _SimpleCompleter<T> {
  T? _value;
  bool _completed = false;
  bool get isCompleted => _completed;
  void complete(T value) {
    _value = value;
    _completed = true;
  }
  Future<T> get future async {
    while (!_completed) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    return _value as T;
  }
}
