import 'package:flutter/material.dart';

/// Le logo VidéoLib : triangle play avec gradient bleu→violet
/// comme sur l'écran de démarrage de la maquette.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const AppLogo({super.key, this.size = 80, this.showShadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
                  blurRadius: size * 0.4,
                  spreadRadius: size * 0.05,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _TrianglePainter(size: size),
      ),
    );
  }
}

/// Dessine le triangle "play" avec une légère ombre interne
class _TrianglePainter extends CustomPainter {
  final double size;
  _TrianglePainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final s = size * 0.32; // demi-taille du triangle

    // Triangle pointant à droite (play)
    // Légèrement décalé à droite du centre comme sur la maquette
    final left = cx - s * 0.6;
    final right = cx + s * 0.9;
    final top = cy - s;
    final bottom = cy + s;

    final path = Path()
      ..moveTo(left, top)
      ..lineTo(right, cy)
      ..lineTo(left, bottom)
      ..close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Légère ombre portée sur le triangle
    canvas.drawShadow(path, Colors.black38, 4, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.size != size;
}
