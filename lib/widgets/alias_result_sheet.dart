import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AliasResultSheet extends StatefulWidget {
  final String alias;
  final VoidCallback onScanAgain;
  const AliasResultSheet({super.key, required this.alias, required this.onScanAgain});

  @override
  State<AliasResultSheet> createState() => _AliasResultSheetState();
}

class _AliasResultSheetState extends State<AliasResultSheet> {
  bool _opened = false;
  static const _platform = MethodChannel('com.biyuyapp/launcher');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _copyAndOpen());
  }

  Future<void> _copyAndOpen() async {
    if (_opened) return;
    _opened = true;
    await Clipboard.setData(ClipboardData(text: widget.alias));
    try {
      await _platform.invokeMethod('launchApp', {
        'package': 'com.mercadopago.wallet',
        'activity': 'com.mercadopago.wallet.SplashActivityAliasDefault',
      });
    } catch (e) {
      await launchUrl(
        Uri.parse('https://www.mercadopago.com.ar/transfer'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Widget _outlineText(String text, double size, Color fill, Color outline) {
    return Stack(
      children: [
        Text(text, style: TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: size,
          foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = outline,
        )),
        Text(text, style: TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: size, color: fill,
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCvu = RegExp(r'^\d{22}$').hasMatch(widget.alias);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF0FDF4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF064E3B), width: 3)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF064E3B), width: 1.5),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF064E3B), width: 3),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 14),

          _outlineText(
            isCvu ? 'CVU detectado!' : 'Alias detectado!',
            22, const Color(0xFF10B981), const Color(0xFF064E3B),
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF064E3B), width: 2.5),
            ),
            child: Text(
              widget.alias,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF064E3B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),

          const Text(
            '📋 Copiado · 🚀 Abriendo MercadoPago...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _copyAndOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF064E3B), width: 2.5),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              label: const Text(
                'Abrir MercadoPago',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onScanAgain();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF064E3B),
                side: const BorderSide(color: Color(0xFF064E3B), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text(
                'Escanear otro alias',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
