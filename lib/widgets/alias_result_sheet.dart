import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentApp {
  final String name;
  final String package;
  final String? activity;
  final String fallbackUrl;
  final Color color;
  final Color textColor;
  final String logoAsset;

  const PaymentApp({
    required this.name,
    required this.package,
    this.activity,
    required this.fallbackUrl,
    required this.color,
    this.textColor = Colors.white,
    required this.logoAsset,
  });
}

const List<PaymentApp> kPaymentApps = [
  PaymentApp(
    name: 'MercadoPago',
    package: 'com.mercadopago.wallet',
    activity: 'com.mercadopago.wallet.SplashActivityAliasDefault',
    fallbackUrl: 'https://www.mercadopago.com.ar/transfer',
    color: Color(0xFF009EE3),
    logoAsset: 'mercadopago',
  ),
  PaymentApp(
    name: 'Modo',
    package: 'com.playdigital.modo',
    activity: 'com.playdigital.modo.MainActivity',
    fallbackUrl: 'https://www.modo.com.ar',
    color: Color(0xFF1A9E4B),
    logoAsset: 'modo',
  ),
  PaymentApp(
    name: 'Personal Pay',
    package: 'ar.com.personalpay',
    fallbackUrl: 'https://personalpay.com.ar',
    color: Color(0xFF5B5BD6),
    logoAsset: 'personalpay',
  ),
  PaymentApp(
    name: 'Naranja X',
    package: 'com.tarjetanaranja.ncuenta',
    fallbackUrl: 'https://www.naranjax.com',
    color: Color(0xFFFF4713),
    logoAsset: 'naranjax',
  ),
  PaymentApp(
    name: 'Cuenta DNI',
    package: 'ar.gob.bna.cuentadni',
    fallbackUrl: 'https://www.bna.com.ar',
    color: Color(0xFF3DAA5C),
    logoAsset: 'cuentadni',
  ),
  PaymentApp(
    name: 'BBVA',
    package: 'ar.com.bbva.net',
    fallbackUrl: 'https://www.bbva.com.ar',
    color: Color(0xFF004481),
    logoAsset: 'bbva',
  ),
  PaymentApp(
    name: 'Uala',
    package: 'ar.com.uala',
    fallbackUrl: 'https://www.uala.com.ar',
    color: Color(0xFF7B2FBE),
    logoAsset: 'uala',
  ),
  PaymentApp(
    name: 'Brubank',
    package: 'com.brubank',
    fallbackUrl: 'https://www.brubank.com',
    color: Color(0xFF00C2A8),
    logoAsset: 'brubank',
  ),
  PaymentApp(
    name: 'Macro',
    package: 'ar.com.macro',
    fallbackUrl: 'https://www.macro.com.ar',
    color: Color(0xFFFFD100),
    textColor: Color(0xFF1A1A1A),
    logoAsset: 'macro',
  ),
  PaymentApp(
    name: 'Galicia',
    package: 'ar.com.galicia.bancamovil',
    fallbackUrl: 'https://www.galicia.ar',
    color: Color(0xFFE2001A),
    logoAsset: 'galicia',
  ),
];

class AliasResultSheet extends StatefulWidget {
  final String alias;
  final VoidCallback onScanAgain;
  const AliasResultSheet({super.key, required this.alias, required this.onScanAgain});

  @override
  State<AliasResultSheet> createState() => _AliasResultSheetState();
}

class _AliasResultSheetState extends State<AliasResultSheet> {
  static const _platform = MethodChannel('com.biyuyapp/launcher');
  List<PaymentApp> _installedApps = [];
  bool _loading = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await Clipboard.setData(ClipboardData(text: widget.alias));
    setState(() => _copied = true);

    final packages = kPaymentApps.map((a) => a.package).toList();
    List<String> installed = [];
    try {
      final result = await _platform.invokeMethod('getInstalledApps', {'packages': packages});
      installed = List<String>.from(result);
    } catch (e) {
      for (final app in kPaymentApps) {
        try {
          final ok = await _platform.invokeMethod('isAppInstalled', {'package': app.package});
          if (ok == true) installed.add(app.package);
        } catch (_) {}
      }
    }

    debugPrint("INSTALLED PACKAGES: $installed");
    final installedApps = kPaymentApps.where((a) => installed.contains(a.package)).toList();
    debugPrint("INSTALLED APPS: ${installedApps.map((a) => a.name).toList()}");

    if (!mounted) return;
    setState(() {
      _installedApps = installedApps;
      _loading = false;
    });

    if (installedApps.length == 1) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _openApp(installedApps.first);
    }
  }

  Future<void> _openApp(PaymentApp app) async {
    try {
      await _platform.invokeMethod('launchApp', {
        'package': app.package,
        if (app.activity != null) 'activity': app.activity,
      });
    } catch (e) {
      await launchUrl(Uri.parse(app.fallbackUrl), mode: LaunchMode.externalApplication);
    }
  }

  Widget _outlineText(String text, double size, Color fill, Color outline) {
    return Stack(children: [
      Text(text, style: TextStyle(
        fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: size,
        foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = outline,
      )),
      Text(text, style: TextStyle(
        fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: size, color: fill,
      )),
    ]);
  }

  Widget _appLogo(PaymentApp app, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logos/${app.logoAsset}.png',
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size, height: size,
          decoration: BoxDecoration(color: app.color, borderRadius: BorderRadius.circular(size * 0.22)),
          child: Center(child: Text(app.name[0], style: TextStyle(color: app.textColor, fontSize: size * 0.4, fontWeight: FontWeight.w900, fontFamily: 'Nunito'))),
        ),
      ),
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
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF064E3B), width: 2.5),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _outlineText(
                      isCvu ? 'CVU detectado!' : 'Alias detectado!',
                      18, const Color(0xFF10B981), const Color(0xFF064E3B),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _copied ? '📋 Copiado al portapapeles' : 'Copiando...',
                      style: const TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                        fontSize: 12, color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF064E3B), width: 2.5),
            ),
            child: Text(
              widget.alias,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                fontSize: 17, color: Color(0xFF064E3B), letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          else if (_installedApps.isEmpty)
            _buildNoAppsFound()
          else ...[
            Row(
              children: [
                const Text(
                  '¿Con qué app pagás?',
                  style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                    fontSize: 14, color: Color(0xFF064E3B),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_installedApps.length} instalada${_installedApps.length > 1 ? "s" : ""}',
                  style: const TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                    fontSize: 12, color: Color(0xFF6EE7B7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _installedApps.length <= 3 ? _installedApps.length : 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: _installedApps.length,
              itemBuilder: (context, index) {
                final app = _installedApps[index];
                return GestureDetector(
                  onTap: () => _openApp(app),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF064E3B), width: 2),
                          boxShadow: [BoxShadow(color: app.color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _appLogo(app, 60),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        app.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                          fontSize: 10, color: Color(0xFF064E3B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: () { Navigator.of(context).pop(); widget.onScanAgain(); },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF064E3B),
                side: const BorderSide(color: Color(0xFF064E3B), width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Escanear otro alias',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAppsFound() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          const Text('No se encontraron apps de pago instaladas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF064E3B))),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://www.mercadopago.com.ar/transfer'), mode: LaunchMode.externalApplication),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009EE3), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF064E3B), width: 2)),
                elevation: 0,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir MercadoPago Web',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
