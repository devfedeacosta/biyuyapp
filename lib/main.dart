import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Added this import
import 'screens/scanner_screen.dart';
import 'services/ocr_service.dart';

void main() async {
  // Ensure Flutter is ready for async calls before runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Load the .env file from your assets
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
    // Handle the error or provide a fallback if necessary
  }

  // 3. Grab the key using the name we chose earlier
  final String apiKey = dotenv.env['Cloud_Vision_API_Key'] ?? '';

  final ocrService = OcrService();
  
  // 4. Initialize the service with the key from the .env file
  await ocrService.init(apiKey);
  
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
