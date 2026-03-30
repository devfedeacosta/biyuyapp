import 'package:flutter/material.dart';
import 'screens/scanner_screen.dart';
import 'services/ocr_service.dart';

const String _devApiKey = 'AIzaSyCnMydHQ1wLvoSJOGWX07dtE8cWMZ9YrDY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ocrService = OcrService();
  await ocrService.init(_devApiKey);
  runApp(MPAliasScannerApp(ocrService: ocrService));
}

class MPAliasScannerApp extends StatelessWidget {
  final OcrService ocrService;
  const MPAliasScannerApp({super.key, required this.ocrService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biyuyapp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.light,
        ),
        fontFamily: 'Nunito',
        useMaterial3: true,
      ),
      home: ScannerScreen(ocrService: ocrService),
    );
  }
}
