import 'package:flutter/material.dart';
import 'screens/scanner_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MPAliasScannerApp());
}

class MPAliasScannerApp extends StatelessWidget {
  const MPAliasScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MP Alias Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009EE3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ScannerScreen(),
    );
  }
}
