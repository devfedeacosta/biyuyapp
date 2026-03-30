import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AliasResultSheet extends StatefulWidget {
  final String alias;
  final VoidCallback onScanAgain;

  const AliasResultSheet({
    super.key,
    required this.alias,
    required this.onScanAgain,
  });

  @override
  State<AliasResultSheet> createState() => _AliasResultSheetState();
}

class _AliasResultSheetState extends State<AliasResultSheet> {
  bool _copied = false;

  Future<void> _copyAndOpen() async {
    await Clipboard.setData(ClipboardData(text: widget.alias));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final uri = Uri.parse('https://www.mercadopago.com.ar/transfer');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCvu = RegExp(r'^\d{22}$').hasMatch(widget.alias);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF00C896),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            isCvu ? 'CVU Detectado' : 'Alias Detectado',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF009EE3).withOpacity(0.4),
              ),
            ),
            child: Text(
              widget.alias,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF009EE3),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'El alias se copiará al portapapeles.\nPegalo en MercadoPago para transferir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _copied ? null : _copyAndOpen,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009EE3),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF00C896),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(_copied ? Icons.check : Icons.open_in_new, size: 20),
              label: Text(
                _copied ? '¡Copiado! Abriendo MP...' : 'Copiar y abrir MercadoPago',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Escanear otro alias', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
