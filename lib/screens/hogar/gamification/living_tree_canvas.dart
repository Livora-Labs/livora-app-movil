import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Canvas vectorial orgánico que dibuja el árbol de Livora meciéndose con el viento,
/// con ramas que florecen, hojas que caen y partículas de brisa viva.
class LivingTreeCanvas extends StatefulWidget {
  const LivingTreeCanvas({
    super.key,
    required this.stage, // 1: Semilla, 2: Brote, 3: Árbol Joven, 4: Árbol Dorado
    this.height = 180,
  });

  final int stage;
  final double height;

  @override
  State<LivingTreeCanvas> createState() => _LivingTreeCanvasState();
}

class _LivingTreeCanvasState extends State<LivingTreeCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _windController;

  @override
  void initState() {
    super.initState();
    _windController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _windController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _windController,
      builder: (context, _) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _TreePainter(
            stage: widget.stage,
            windFactor: math.sin(_windController.value * math.pi * 2) * 0.08,
            breathFactor: math.sin(_windController.value * math.pi) * 0.03,
          ),
        );
      },
    );
  }
}

class _TreePainter extends CustomPainter {
  final int stage;
  final double windFactor;
  final double breathFactor;

  _TreePainter({
    required this.stage,
    required this.windFactor,
    required this.breathFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final groundY = size.height * 0.85;

    // 1. Suelo fértil estilizado (Montículo de tierra/césped)
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE2E8F0), Color(0xFFF1F5F9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, groundY - 8, size.width, 24))
      ..style = PaintingStyle.fill;

    final groundPath = Path()
      ..moveTo(cx - 80, groundY)
      ..quadraticBezierTo(cx, groundY - 10, cx + 80, groundY)
      ..lineTo(cx + 80, groundY + 12)
      ..lineTo(cx - 80, groundY + 12)
      ..close();
    canvas.drawPath(groundPath, groundPaint);

    // 2. Partículas flotantes de brisa/polen
    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      final px = cx - 60 + (i * 24) + (windFactor * 80);
      final py = groundY - 40 - (i * 12) + (breathFactor * 30);
      particlePaint.color = stage == 4
          ? const Color(0xFFF59E0B).withOpacity(0.35)
          : const Color(0xFF00E5A3).withOpacity(0.3);
      canvas.drawCircle(Offset(px, py), 2.0 + (i % 2), particlePaint);
    }

    // 3. Renderizado según la etapa evolutiva
    switch (stage) {
      case 1:
        _drawSeedling(canvas, cx, groundY);
        break;
      case 2:
        _drawSprout(canvas, cx, groundY);
        break;
      case 3:
        _drawYoungTree(canvas, cx, groundY);
        break;
      case 4:
      default:
        _drawGoldenTree(canvas, cx, groundY);
        break;
    }
  }

  /// Etapa 1: Semilla Germinada con dos hojitas saliendo de la tierra
  void _drawSeedling(Canvas canvas, double cx, double groundY) {
    // Semilla
    final seedPaint = Paint()
      ..color = const Color(0xFF8B5A2B)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, groundY - 2), width: 14, height: 10),
      seedPaint,
    );

    // Tallo oscilando
    final stemPaint = Paint()
      ..color = const Color(0xFF00A878)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tipX = cx + (windFactor * 30);
    final tipY = groundY - 26;

    final stemPath = Path()
      ..moveTo(cx, groundY - 4)
      ..quadraticBezierTo(cx + (windFactor * 10), groundY - 14, tipX, tipY);
    canvas.drawPath(stemPath, stemPaint);

    // Dos hojitas tiernas
    final leafPaint = Paint()
      ..color = const Color(0xFF00E5A3)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(tipX, tipY);
    canvas.rotate(windFactor * 0.8);

    // Hoja izquierda
    final leftLeaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-8, -6, -14, -2)
      ..quadraticBezierTo(-8, 4, 0, 0);
    canvas.drawPath(leftLeaf, leafPaint);

    // Hoja derecha
    final rightLeaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(8, -8, 14, -3)
      ..quadraticBezierTo(8, 3, 0, 0);
    canvas.drawPath(rightLeaf, leafPaint);

    canvas.restore();
  }

  /// Etapa 2: Brote con tallo más alto y 4 ramas con hojas vivas
  void _drawSprout(Canvas canvas, double cx, double groundY) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF006852)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final trunkTopX = cx + (windFactor * 45);
    final trunkTopY = groundY - 55;

    final trunkPath = Path()
      ..moveTo(cx, groundY - 2)
      ..quadraticBezierTo(cx + (windFactor * 15), groundY - 28, trunkTopX, trunkTopY);
    canvas.drawPath(trunkPath, trunkPaint);

    // Follaje de brote
    _drawLeafCluster(canvas, trunkTopX, trunkTopY, 18, const Color(0xFF00A878));
    _drawLeafCluster(canvas, trunkTopX - 14, trunkTopY + 14, 13, const Color(0xFF00E5A3));
    _drawLeafCluster(canvas, trunkTopX + 14, trunkTopY + 12, 14, const Color(0xFF10B981));
  }

  /// Etapa 3: Árbol Joven con ramas firmes, copa amplia y flores nacientes
  void _drawYoungTree(Canvas canvas, double cx, double groundY) {
    // Tronco leñoso
    final trunkPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final topX = cx + (windFactor * 50);
    final topY = groundY - 75;

    final trunkPath = Path()
      ..moveTo(cx, groundY)
      ..quadraticBezierTo(cx + (windFactor * 18), groundY - 38, topX, topY);
    canvas.drawPath(trunkPath, trunkPaint);

    // Ramas secundarias
    final branchPaint = Paint()
      ..color = const Color(0xFF6D4C41)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(cx + (windFactor * 12), groundY - 42),
      Offset(topX - 22, topY + 14),
      branchPaint,
    );
    canvas.drawLine(
      Offset(cx + (windFactor * 14), groundY - 48),
      Offset(topX + 22, topY + 12),
      branchPaint,
    );

    // Copa frondosa esmeralda
    _drawLeafCluster(canvas, topX, topY - 12, 28, const Color(0xFF00A878));
    _drawLeafCluster(canvas, topX - 24, topY + 4, 22, const Color(0xFF006852));
    _drawLeafCluster(canvas, topX + 24, topY + 2, 22, const Color(0xFF10B981));
    _drawLeafCluster(canvas, topX, topY + 12, 24, const Color(0xFF00B4D8));

    // Pequeños frutos/flores rosáceas/doradas
    final blossomPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(topX - 12, topY - 6), 3.5, blossomPaint);
    canvas.drawCircle(Offset(topX + 14, topY - 2), 3.5, blossomPaint);
    canvas.drawCircle(Offset(topX + 2, topY + 16), 3.5, blossomPaint);
  }

  /// Etapa 4: Gran Árbol Dorado con resplandor sagrado, aura de destello y corona
  void _drawGoldenTree(Canvas canvas, double cx, double groundY) {
    final topX = cx + (windFactor * 55);
    final topY = groundY - 88;

    // 1. Aura resplandeciente exterior
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF59E0B).withOpacity(0.25 + breathFactor * 2),
          const Color(0xFFFBBF24).withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(topX, topY), radius: 75));
    canvas.drawCircle(Offset(topX, topY), 75, auraPaint);

    // 2. Tronco majestuoso de caoba
    final trunkPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = 9.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final trunkPath = Path()
      ..moveTo(cx, groundY)
      ..quadraticBezierTo(cx + (windFactor * 20), groundY - 44, topX, topY);
    canvas.drawPath(trunkPath, trunkPaint);

    // Ramas doradas
    final branchPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(cx + (windFactor * 14), groundY - 50),
      Offset(topX - 32, topY + 16),
      branchPaint,
    );
    canvas.drawLine(
      Offset(cx + (windFactor * 16), groundY - 56),
      Offset(topX + 32, topY + 14),
      branchPaint,
    );

    // 3. Copa Frondosa Dorada y Esmeralda
    _drawLeafCluster(canvas, topX, topY - 18, 34, const Color(0xFFF59E0B));
    _drawLeafCluster(canvas, topX - 30, topY + 4, 28, const Color(0xFF00A878));
    _drawLeafCluster(canvas, topX + 30, topY + 2, 28, const Color(0xFFEAB308));
    _drawLeafCluster(canvas, topX - 12, topY - 32, 26, const Color(0xFFFBBF24));
    _drawLeafCluster(canvas, topX + 12, topY - 30, 26, const Color(0xFF10B981));
    _drawLeafCluster(canvas, topX, topY + 12, 30, const Color(0xFF006852));

    // 4. Corona dorada de honor flotante sobre la copa
    final crownPaint = Paint()
      ..color = const Color(0xFFEAB308)
      ..style = PaintingStyle.fill;

    final crownCenterY = topY - 56 + (breathFactor * 15);
    final crownPath = Path()
      ..moveTo(topX - 14, crownCenterY + 4)
      ..lineTo(topX - 14, crownCenterY - 6)
      ..lineTo(topX - 7, crownCenterY - 1)
      ..lineTo(topX, crownCenterY - 9)
      ..lineTo(topX + 7, crownCenterY - 1)
      ..lineTo(topX + 14, crownCenterY - 6)
      ..lineTo(topX + 14, crownCenterY + 4)
      ..close();
    canvas.drawPath(crownPath, crownPaint);

    // Gemas de la corona
    final gemPaint = Paint()..color = const Color(0xFF00E5A3)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(topX, crownCenterY - 2), 2.2, gemPaint);
  }

  void _drawLeafCluster(Canvas canvas, double x, double y, double radius, Color color) {
    final clusterPaint = Paint()
      ..color = color.withOpacity(0.92)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), radius, clusterPaint);
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) => true;
}
