import 'package:flutter/material.dart';

class ScannerOverlay extends StatefulWidget {
  final String statusMessage;
  final bool aliasDetected;
  final String? detectedAlias;

  const ScannerOverlay({
    super.key,
    required this.statusMessage,
    required this.aliasDetected,
    this.detectedAlias,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxWidth = size.width * 0.8;
    const boxHeight = 180.0;
    final boxLeft = (size.width - boxWidth) / 2;
    final boxTop = size.height * 0.35;

    final borderColor = widget.aliasDetected
        ? const Color(0xFF00C896)
        : const Color(0xFF009EE3);

    return Stack(
      children: [
        CustomPaint(
          size: size,
          painter: _OverlayPainter(
            boxRect: Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
          ),
        ),
        if (!widget.aliasDetected)
          AnimatedBuilder(
            animation: _scanLineAnim,
            builder: (context, child) {
              return Positioned(
                left: boxLeft + 8,
                top: boxTop + 8 + (_scanLineAnim.value * (boxHeight - 16)),
                child: Container(
                  width: boxWidth - 16,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF009EE3).withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        Positioned(
          left: boxLeft,
          top: boxTop,
          child: _ScanFrame(width: boxWidth, height: boxHeight, color: borderColor),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: boxTop + boxHeight + 20,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              widget.statusMessage,
              key: ValueKey(widget.statusMessage),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: borderColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: boxTop - 48,
          child: const Text(
            'Encuadra el alias dentro del recuadro',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect boxRect;
  _OverlayPainter({required this.boxRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.boxRect != boxRect;
}

class _ScanFrame extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _ScanFrame({required this.width, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _FramePainter(color: color)),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Color color;
  _FramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;
    const r = 12.0;
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
        Path()
          ..moveTo(0, cornerLen + r)
          ..lineTo(0, r)
          ..arcToPoint(Offset(r, 0), radius: const Radius.circular(r), clockwise: true)
          ..lineTo(cornerLen + r, 0),
        paint);

    canvas.drawPath(
        Path()
          ..moveTo(w - cornerLen - r, 0)
          ..lineTo(w - r, 0)
          ..arcToPoint(Offset(w, r), radius: const Radius.circular(r), clockwise: true)
          ..lineTo(w, cornerLen + r),
        paint);

    canvas.drawPath(
        Path()
          ..moveTo(0, h - cornerLen - r)
          ..lineTo(0, h - r)
          ..arcToPoint(Offset(r, h), radius: const Radius.circular(r), clockwise: false)
          ..lineTo(cornerLen + r, h),
        paint);

    canvas.drawPath(
        Path()
          ..moveTo(w - cornerLen - r, h)
          ..lineTo(w - r, h)
          ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r), clockwise: false)
          ..lineTo(w, h - cornerLen - r),
        paint);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color;
}
