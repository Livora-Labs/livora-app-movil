import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Escenario Ilustrado Orgánico con Sombras y Profundidad 2.5D de Grado Profesional.
/// Características de vanguardia:
/// - Atmósfera dinámica según la hora real del dispositivo (Amanecer / Día / Atardecer / Noche estrellada).
/// - Noche con constelaciones suaves y enjambre de luciérnagas bioluminiscentes parpadeantes.
/// - Día con rayos de sol volumétricos ("God Rays") y nubes con sombras basales.
/// - Texturas naturales: Vetas leñosas en el tronco, raíces expuestas sobre tierra con piedras minerales,
///   césped con flores silvestres y racimos de hojas individuales en la copa.
/// - Física táctil orgánica: Al tocar el árbol, las ramas oscilan con elasticidad elástica y caen hojas meciéndose.
class ParallaxEcosystemCanvas extends StatefulWidget {
  const ParallaxEcosystemCanvas({
    super.key,
    required this.stage, // 1: Semilla, 2: Brote, 3: Árbol Joven, 4: Árbol Dorado
    this.height = 340,
  });

  final int stage;
  final double height;

  @override
  State<ParallaxEcosystemCanvas> createState() => _ParallaxEcosystemCanvasState();
}

class _FallingLeaf {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double vRot;
  double size;
  Color color;

  _FallingLeaf({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.vRot,
    required this.size,
    required this.color,
  });
}

class _ParallaxEcosystemCanvasState extends State<ParallaxEcosystemCanvas>
    with TickerProviderStateMixin {
  late AnimationController _windController;
  late AnimationController _butterflyController;
  late AnimationController _cloudController;
  late AnimationController _springController;

  final List<_FallingLeaf> _fallingLeaves = [];
  double _touchOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _windController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);

    _butterflyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();

    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..repeat();

    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _springController.addListener(() {
      // Movimiento amortiguado de muelle al soltar
      final t = _springController.value;
      _touchOffset = math.sin(t * math.pi * 4) * (1 - t) * 14.0;
      _updateFallingLeaves();
      setState(() {});
    });
  }

  void _triggerTreeTouch(Offset localPos, Size size) {
    HapticFeedback.lightImpact();
    _springController.forward(from: 0.0);

    // Generar 3 a 5 hojas que caen mecidas por la brisa
    final isGolden = widget.stage == 4;
    final leafColors = isGolden
        ? [const Color(0xFFFDE047), const Color(0xFFF59E0B), const Color(0xFF10B981)]
        : [const Color(0xFF00E5A3), const Color(0xFF00A878), const Color(0xFF10B981)];

    final rnd = math.Random();
    final treeCenterX = size.width * 0.5;
    final treeCenterY = size.height * 0.55;

    for (int i = 0; i < 4; i++) {
      _fallingLeaves.add(
        _FallingLeaf(
          x: treeCenterX + (rnd.nextDouble() - 0.5) * 60,
          y: treeCenterY + (rnd.nextDouble() - 0.5) * 40,
          vx: (rnd.nextDouble() - 0.5) * 1.5,
          vy: 1.2 + rnd.nextDouble() * 1.8,
          rotation: rnd.nextDouble() * math.pi * 2,
          vRot: (rnd.nextDouble() - 0.5) * 0.2,
          size: 6.0 + rnd.nextDouble() * 5.0,
          color: leafColors[rnd.nextInt(leafColors.length)],
        ),
      );
    }
    if (_fallingLeaves.length > 25) {
      _fallingLeaves.removeRange(0, _fallingLeaves.length - 25);
    }
  }

  void _updateFallingLeaves() {
    for (final leaf in _fallingLeaves) {
      leaf.x += leaf.vx + math.sin(leaf.y * 0.05) * 0.8;
      leaf.y += leaf.vy;
      leaf.rotation += leaf.vRot;
    }
    _fallingLeaves.removeWhere((l) => l.y > widget.height + 20);
  }

  void _disposeControllers() {
    _windController.dispose();
    _butterflyController.dispose();
    _cloudController.dispose();
    _springController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _triggerTreeTouch(details.localPosition, Size(MediaQuery.of(context).size.width, widget.height)),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _windController,
          _butterflyController,
          _cloudController,
        ]),
        builder: (context, _) {
          final now = DateTime.now();
          // Calcular ciclo solar/nocturno astronómico según la hora local:
          // 06:00 a 17:30 = Día
          // 17:30 a 19:15 = Atardecer
          // 19:15 a 06:00 = Noche
          final hourDecimal = now.hour + (now.minute / 60.0);
          final isNight = hourDecimal >= 19.25 || hourDecimal < 6.0;
          final isSunset = !isNight && (hourDecimal >= 17.5 && hourDecimal < 19.25);

          final wind = math.sin(_windController.value * math.pi * 2) * 0.07;
          final breath = math.sin(_windController.value * math.pi) * 0.04;
          final butterflyPhase = _butterflyController.value;
          final cloudPhase = _cloudController.value;

          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _ForestDioramaPainter(
              stage: widget.stage,
              windFactor: wind,
              breathFactor: breath,
              butterflyPhase: butterflyPhase,
              cloudPhase: cloudPhase,
              touchOffset: _touchOffset,
              fallingLeaves: _fallingLeaves,
              isNight: isNight,
              isSunset: isSunset,
            ),
          );
        },
      ),
    );
  }
}

class _ForestDioramaPainter extends CustomPainter {
  final int stage;
  final double windFactor;
  final double breathFactor;
  final double butterflyPhase;
  final double cloudPhase;
  final double touchOffset;
  final List<_FallingLeaf> fallingLeaves;
  final bool isNight;
  final bool isSunset;

  _ForestDioramaPainter({
    required this.stage,
    required this.windFactor,
    required this.breathFactor,
    required this.butterflyPhase,
    required this.cloudPhase,
    required this.touchOffset,
    required this.fallingLeaves,
    required this.isNight,
    required this.isSunset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final isGolden = stage == 4;

    // 1. Bóveda Atmosférica (Día, Atardecer o Noche Estrellada)
    _drawAtmosphere(canvas, w, h, isGolden);

    // 2. Luminaria Celeste (Sol diurno, Sol poniente o Luna creciente nocturna)
    _drawCelestialBody(canvas, w, h, isGolden);

    // 3. Rayos de Sol Volumétricos (God Rays) durante el día / atardecer
    if (!isNight) {
      _drawGodRays(canvas, w, h);
    }

    // 4. Nubes volumétricas 2.5D
    if (!isNight) {
      _drawVolumetricCloud(canvas, (cloudPhase * w * 1.3) % (w + 140) - 70, h * 0.15, 65);
      _drawVolumetricCloud(canvas, ((cloudPhase * 0.7 + 0.45) * w * 1.3) % (w + 160) - 80, h * 0.25, 48);
    }

    // 5. Cordillera Lejana
    _drawDistantMountains(canvas, w, h);

    // 6. Colinas Intermedias Esmeralda
    _drawMidHills(canvas, w, h);

    // 7. Montículo y Suelo Orgánico con Raíces Expuestas y Piedras
    final groundY = h * 0.84;
    final cx = w * 0.5;
    _drawOrganicGround(canvas, w, h, groundY, cx);

    // 8. Césped y Flores Silvestres
    _drawWildFlowersAndGrass(canvas, w, groundY, cx);

    // 9. Sombra de Contacto
    final treeBaseY = groundY - 26;
    _drawGroundShadow(canvas, cx, treeBaseY);

    // 10. Árbol con Vetas Leñosas, Copa Multicapa y Física Táctil
    canvas.save();
    canvas.translate(touchOffset * 0.4, 0);
    switch (stage) {
      case 1:
        _drawOrganicSeedling(canvas, cx, treeBaseY);
        break;
      case 2:
        _drawOrganicSprout(canvas, cx, treeBaseY);
        break;
      case 3:
        _drawOrganicYoungTree(canvas, cx, treeBaseY);
        break;
      case 4:
      default:
        _drawOrganicGoldenTree(canvas, cx, treeBaseY);
        break;
    }
    canvas.restore();

    // 11. Hojas Cayendo Mecidas por la Brisa
    _drawFallingLeaves(canvas);

    // 12. Fauna y Partículas Vivas: Mariposas de Día o Luciérnagas de Noche
    if (isNight) {
      _drawFireflies(canvas, cx, treeBaseY);
    } else {
      _drawButterflies(canvas, cx, treeBaseY, isGolden);
    }
  }

  void _drawAtmosphere(Canvas canvas, double w, double h, bool isGolden) {
    final skyRect = Rect.fromLTWH(0, 0, w, h);
    List<Color> skyColors;
    List<double> stops;

    if (isNight) {
      skyColors = const [
        Color(0xFF0F172A), // Azul noche profundo
        Color(0xFF1E293B), // Bóveda índigo
        Color(0xFF064E3B), // Horizonte boscoso nocturno
      ];
      stops = const [0.0, 0.6, 1.0];
    } else if (isSunset) {
      skyColors = const [
        Color(0xFF7C3AED), // Violeta crepuscular cenital
        Color(0xFFF97316), // Naranja atardecer dorado
        Color(0xFFFDE047), // Resplandor ámbar en horizonte
      ];
      stops = const [0.0, 0.5, 1.0];
    } else if (isGolden) {
      skyColors = const [
        Color(0xFFFEF08A),
        Color(0xFFBAE6FD),
        Color(0xFFDCFCE7),
      ];
      stops = const [0.0, 0.55, 1.0];
    } else {
      skyColors = const [
        Color(0xFF38BDF8),
        Color(0xFFBAE6FD),
        Color(0xFFF0FDF4),
      ];
      stops = const [0.0, 0.55, 1.0];
    }

    final skyPaint = Paint()
      ..shader = LinearGradient(
        colors: skyColors,
        stops: stops,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // Si es de noche, dibujar campo de estrellas titilantes
    if (isNight) {
      final starPaint = Paint()..color = Colors.white.withOpacity(0.85);
      final rnd = math.Random(42); // Seed fija para constelaciones estables
      for (int i = 0; i < 48; i++) {
        final sx = rnd.nextDouble() * w;
        final sy = rnd.nextDouble() * (h * 0.65);
        final starRadius = (rnd.nextDouble() * 1.5) + (math.sin(cloudPhase * 20 + i) * 0.4);
        canvas.drawCircle(Offset(sx, sy), math.max(0.6, starRadius), starPaint);
      }
    }
  }

  void _drawCelestialBody(Canvas canvas, double w, double h, bool isGolden) {
    final sunX = w * 0.78;
    final sunY = h * 0.2;

    if (isNight) {
      // Luna creciente suave
      final moonPaint = Paint()
        ..color = const Color(0xFFFEF9C3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(sunX, sunY), 22, moonPaint);
      // Sombra para fase creciente
      final cutoutPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawCircle(Offset(sunX - 7, sunY - 4), 19, cutoutPaint);

      // Halo lunar
      final moonGlow = Paint()
        ..color = const Color(0xFFFEF9C3).withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(Offset(sunX, sunY), 45, moonGlow);
    } else {
      // Sol diurno o atardecer
      final auraColor = isSunset ? const Color(0xFFFB923C) : (isGolden ? const Color(0xFFF59E0B) : const Color(0xFFFDE047));
      final aura1 = Paint()
        ..shader = RadialGradient(
          colors: [
            auraColor.withOpacity(0.35 + breathFactor * 2),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(sunX, sunY), radius: 64));
      canvas.drawCircle(Offset(sunX, sunY), 64, aura1);

      final aura2 = Paint()
        ..color = (isSunset ? const Color(0xFFF97316) : const Color(0xFFFEF08A)).withOpacity(0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(sunX, sunY), 26, aura2);

      final sunCore = Paint()..color = isSunset ? const Color(0xFFFFF7ED) : Colors.white;
      canvas.drawCircle(Offset(sunX, sunY), 18, sunCore);
    }
  }

  void _drawGodRays(Canvas canvas, double w, double h) {
    final sunX = w * 0.78;
    final sunY = h * 0.2;
    final rayPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, sunY, w, h - sunY));

    for (int i = 0; i < 4; i++) {
      final ray = Path()
        ..moveTo(sunX - 8 + (i * 12), sunY)
        ..lineTo(w * (0.15 + i * 0.22), h)
        ..lineTo(w * (0.28 + i * 0.22), h)
        ..close();
      canvas.drawPath(ray, rayPaint);
    }
  }

  void _drawVolumetricCloud(Canvas canvas, double x, double y, double r) {
    final shadowPaint = Paint()..color = const Color(0xFFCBD5E1).withOpacity(0.35);
    canvas.drawCircle(Offset(x + 2, y + 4), r * 0.45, shadowPaint);
    canvas.drawCircle(Offset(x + r * 0.4 + 2, y - r * 0.1 + 4), r * 0.38, shadowPaint);

    final bodyPaint = Paint()..color = Colors.white.withOpacity(0.92);
    canvas.drawCircle(Offset(x, y), r * 0.45, bodyPaint);
    canvas.drawCircle(Offset(x + r * 0.4, y - r * 0.1), r * 0.38, bodyPaint);
    canvas.drawCircle(Offset(x - r * 0.35, y + r * 0.05), r * 0.32, bodyPaint);

    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - r * 0.45, y, r * 1.0, r * 0.38),
      Radius.circular(r * 0.2),
    );
    canvas.drawRRect(baseRect, bodyPaint);
  }

  void _drawDistantMountains(Canvas canvas, double w, double h) {
    final distantHillsPaint = Paint()
      ..shader = LinearGradient(
        colors: isNight
            ? [const Color(0xFF0F172A).withOpacity(0.7), const Color(0xFF1E293B).withOpacity(0.5)]
            : (isSunset
                ? [const Color(0xFF4C1D95).withOpacity(0.6), const Color(0xFF7C3AED).withOpacity(0.4)]
                : [const Color(0xFF6EE7B7).withOpacity(0.45), const Color(0xFFA7F3D0).withOpacity(0.2)]),
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, h * 0.58, w, h * 0.42));

    final distantHills = Path()
      ..moveTo(0, h * 0.68)
      ..quadraticBezierTo(w * 0.22, h * 0.56, w * 0.52, h * 0.65)
      ..quadraticBezierTo(w * 0.78, h * 0.72, w, h * 0.61)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(distantHills, distantHillsPaint);
  }

  void _drawMidHills(Canvas canvas, double w, double h) {
    final midHillsPaint = Paint()
      ..shader = LinearGradient(
        colors: isNight
            ? const [Color(0xFF064E3B), Color(0xFF022C22)]
            : (isSunset
                ? const [Color(0xFFB45309), Color(0xFF78350F)]
                : const [Color(0xFF34D399), Color(0xFF059669)]),
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, h * 0.68, w, h * 0.32));

    final midHills = Path()
      ..moveTo(0, h * 0.75)
      ..quadraticBezierTo(w * 0.28, h * 0.69, w * 0.62, h * 0.76)
      ..quadraticBezierTo(w * 0.85, h * 0.8, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(midHills, midHillsPaint);
  }

  void _drawOrganicGround(Canvas canvas, double w, double h, double groundY, double cx) {
    final moundShadow = Path()
      ..moveTo(0, groundY)
      ..quadraticBezierTo(cx, groundY - 35, w, groundY + 4)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final moundPaint = Paint()
      ..shader = LinearGradient(
        colors: isNight
            ? const [Color(0xFF064E3B), Color(0xFF022C22), Color(0xFF021611)]
            : (isSunset
                ? const [Color(0xFFD97706), Color(0xFF78350F), Color(0xFF451A03)]
                : const [Color(0xFF00A878), Color(0xFF006852), Color(0xFF004D40)]),
        stops: const [0.0, 0.45, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, groundY - 35, w, h - groundY + 35));
    canvas.drawPath(moundShadow, moundPaint);

    // Piedras minerales y textura de tierra orgánica
    final stonePaint = Paint()..color = const Color(0xFF475569).withOpacity(0.5);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 68, groundY + 8), width: 14, height: 7), stonePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 74, groundY + 12), width: 18, height: 9), stonePaint);

    // Raíces expuestas leñosas brotando del tronco hacia el montículo
    if (stage >= 2) {
      final rootPaint = Paint()
        ..color = const Color(0xFF3E2723)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Raíz izquierda
      final rootLeft = Path()
        ..moveTo(cx - 3, groundY - 22)
        ..quadraticBezierTo(cx - 18, groundY - 14, cx - 32, groundY - 4);
      canvas.drawPath(rootLeft, rootPaint);

      // Raíz derecha
      final rootRight = Path()
        ..moveTo(cx + 4, groundY - 22)
        ..quadraticBezierTo(cx + 20, groundY - 12, cx + 36, groundY - 6);
      canvas.drawPath(rootRight, rootPaint);
    }
  }

  void _drawWildFlowersAndGrass(Canvas canvas, double w, double groundY, double cx) {
    final grassPaint = Paint()
      ..color = isNight ? const Color(0xFF10B981) : const Color(0xFF00E5A3)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final flowerColors = [
      const Color(0xFFF43F5E),
      const Color(0xFFFBBF24),
      const Color(0xFF38BDF8),
    ];

    for (int i = 0; i < 24; i++) {
      final gx = 25.0 + (i * (w - 50) / 24);
      final distFromCenter = (gx - cx).abs() / cx;
      final gy = groundY - 22 - (1 - distFromCenter) * 12;

      final tilt = windFactor * 45;
      canvas.drawLine(Offset(gx, gy), Offset(gx + tilt, gy - 8), grassPaint);
      canvas.drawLine(Offset(gx - 3, gy + 1), Offset(gx - 3 + tilt * 0.7, gy - 6), grassPaint);

      if (i % 4 == 0) {
        final flowerPaint = Paint()..color = flowerColors[(i ~/ 4) % flowerColors.length];
        canvas.drawCircle(Offset(gx + tilt, gy - 9), 2.8, flowerPaint);
        canvas.drawCircle(Offset(gx + tilt, gy - 9), 1.0, Paint()..color = Colors.white);
      }
    }
  }

  void _drawGroundShadow(Canvas canvas, double cx, double treeBaseY) {
    final shadowPaint = Paint()
      ..color = const Color(0xFF00382B).withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + windFactor * 10, treeBaseY + 6),
        width: stage >= 3 ? 72 : 44,
        height: 14,
      ),
      shadowPaint,
    );
  }

  void _drawOrganicSeedling(Canvas canvas, double cx, double groundY) {
    final seedRect = Rect.fromCenter(center: Offset(cx, groundY + 4), width: 22, height: 14);
    final seedPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B5A2B), Color(0xFF5D3A1A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(seedRect);
    canvas.drawOval(seedRect, seedPaint);

    final tipX = cx + (windFactor * 40);
    final tipY = groundY - 38;

    final stemPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00A878), Color(0xFF00E5A3)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTRB(cx - 10, tipY, cx + 10, groundY))
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final stemPath = Path()
      ..moveTo(cx, groundY + 2)
      ..quadraticBezierTo(cx + (windFactor * 16), groundY - 20, tipX, tipY);
    canvas.drawPath(stemPath, stemPaint);

    _drawVolumetricLeaf(canvas, tipX, tipY, -1, const Color(0xFF00E5A3), const Color(0xFF00A878));
    _drawVolumetricLeaf(canvas, tipX, tipY, 1, const Color(0xFF00A878), const Color(0xFF006852));
  }

  void _drawOrganicSprout(Canvas canvas, double cx, double groundY) {
    final tipX = cx + (windFactor * 52);
    final tipY = groundY - 82;

    // Tronco con vetas de corteza
    _drawBarkTrunk(canvas, cx, groundY + 2, tipX, tipY, 8.5);

    // Follaje multicapa
    _drawFoliageBubble(canvas, tipX - 22, tipY + 16, 20, const Color(0xFF006852), const Color(0xFF004D40));
    _drawFoliageBubble(canvas, tipX + 22, tipY + 14, 22, const Color(0xFF007A5E), const Color(0xFF005842));
    _drawFoliageBubble(canvas, tipX, tipY - 4, 28, const Color(0xFF00E5A3), const Color(0xFF00A878));
  }

  void _drawOrganicYoungTree(Canvas canvas, double cx, double groundY) {
    final topX = cx + (windFactor * 58);
    final topY = groundY - 118;

    // Tronco principal con corteza leñosa rugosa
    _drawBarkTrunk(canvas, cx, groundY + 4, topX, topY, 12.5);

    // Ramas secundarias con luces y sombras
    final branchPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx + windFactor * 16, groundY - 64), Offset(topX - 36, topY + 24), branchPaint);
    canvas.drawLine(Offset(cx + windFactor * 18, groundY - 72), Offset(topX + 38, topY + 22), branchPaint);

    // Copa en 6 esferas volumétricas 2.5D
    _drawFoliageBubble(canvas, topX - 36, topY + 14, 34, const Color(0xFF006852), const Color(0xFF004D40));
    _drawFoliageBubble(canvas, topX + 36, topY + 12, 34, const Color(0xFF00755C), const Color(0xFF00503D));
    _drawFoliageBubble(canvas, topX, topY - 22, 42, const Color(0xFF00E5A3), const Color(0xFF00A878));
    _drawFoliageBubble(canvas, topX - 16, topY + 2, 36, const Color(0xFF10B981), const Color(0xFF047857));
    _drawFoliageBubble(canvas, topX + 18, topY, 36, const Color(0xFF00B4D8), const Color(0xFF0077B6));

    // Frutos silvestres y flores de recompensa
    _drawFruit(canvas, topX - 22, topY - 10, const Color(0xFFF59E0B));
    _drawFruit(canvas, topX + 24, topY - 6, const Color(0xFFFBBF24));
    _drawFruit(canvas, topX + 2, topY + 16, const Color(0xFFF43F5E));
  }

  void _drawOrganicGoldenTree(Canvas canvas, double cx, double groundY) {
    final topX = cx + (windFactor * 64);
    final topY = groundY - 132;

    // Aura celestial palpitante
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF59E0B).withOpacity(0.38 + breathFactor * 2),
          const Color(0xFFFBBF24).withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(topX, topY), radius: 115));
    canvas.drawCircle(Offset(topX, topY), 115, auraPaint);

    // Tronco imperial de madera noble con vetas
    _drawBarkTrunk(canvas, cx, groundY + 4, topX, topY, 15.0);

    // Ramas doradas
    final branchPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx + windFactor * 18, groundY - 76), Offset(topX - 48, topY + 28), branchPaint);
    canvas.drawLine(Offset(cx + windFactor * 20, groundY - 84), Offset(topX + 48, topY + 26), branchPaint);

    // Copa imperial multicapa
    _drawFoliageBubble(canvas, topX - 44, topY + 16, 42, const Color(0xFF00755C), const Color(0xFF004D40));
    _drawFoliageBubble(canvas, topX + 44, topY + 14, 42, const Color(0xFF00A878), const Color(0xFF006852));
    _drawFoliageBubble(canvas, topX, topY - 32, 50, const Color(0xFFFEF08A), const Color(0xFFF59E0B));
    _drawFoliageBubble(canvas, topX - 22, topY - 4, 44, const Color(0xFFFDE047), const Color(0xFFD97706));
    _drawFoliageBubble(canvas, topX + 24, topY - 6, 44, const Color(0xFF00E5A3), const Color(0xFF059669));

    // Corona Real flotante
    final crownCenterY = topY - 86 + (breathFactor * 20);
    _drawGoldenCrown(canvas, topX, crownCenterY);
  }

  void _drawBarkTrunk(Canvas canvas, double x1, double y1, double x2, double y2, double thickness) {
    // 1. Cuerpo principal del tronco con gradiente de luz/sombra
    final trunkPath = Path()
      ..moveTo(x1, y1)
      ..quadraticBezierTo(x1 + (windFactor * 24), (y1 + y2) * 0.5, x2, y2);

    final trunkPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2D1810), Color(0xFF4A2810), Color(0xFF5D3A1A)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(x1 - thickness, y2, thickness * 2, y1 - y2))
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(trunkPath, trunkPaint);

    // 2. Vetas leñosas y rugosidad
    final barkPaint = Paint()
      ..color = const Color(0xFF1E0E08).withOpacity(0.4)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final barkLine1 = Path()
      ..moveTo(x1 - thickness * 0.25, y1 - 10)
      ..quadraticBezierTo(x1 + (windFactor * 20), (y1 + y2) * 0.5 - 5, x2 - thickness * 0.2, y2 + 15);
    canvas.drawPath(barkLine1, barkPaint);

    final barkHighlight = Paint()
      ..color = const Color(0xFF8B5A2B).withOpacity(0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final barkLine2 = Path()
      ..moveTo(x1 + thickness * 0.25, y1 - 8)
      ..quadraticBezierTo(x1 + (windFactor * 26), (y1 + y2) * 0.5 + 5, x2 + thickness * 0.2, y2 + 10);
    canvas.drawPath(barkLine2, barkHighlight);
  }

  void _drawFoliageBubble(Canvas canvas, double x, double y, double radius, Color lightColor, Color shadowColor) {
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(x + 2, y + 4), radius, shadowPaint);

    final bubbleRect = Rect.fromCircle(center: Offset(x, y), radius: radius);
    final bubblePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.85,
        colors: [
          Colors.white.withOpacity(0.45),
          lightColor,
          shadowColor,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bubbleRect);
    canvas.drawCircle(Offset(x, y), radius, bubblePaint);

    // Textura de racimos de hojitas en el borde exterior
    final leafPaint = Paint()..color = lightColor.withOpacity(0.9);
    for (int i = 0; i < 7; i++) {
      final angle = (i * math.pi * 2) / 7;
      final lx = x + math.cos(angle) * (radius - 3);
      final ly = y + math.sin(angle) * (radius - 3);
      canvas.drawCircle(Offset(lx, ly), radius * 0.25, leafPaint);
    }
  }

  void _drawVolumetricLeaf(Canvas canvas, double x, double y, double direction, Color lightColor, Color shadowColor) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(direction * (0.55 + windFactor));

    final shadowHalf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(14 * direction, -12, 22 * direction, -4)
      ..lineTo(0, 0);
    canvas.drawPath(shadowHalf, Paint()..color = shadowColor);

    final lightHalf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(10 * direction, 8, 22 * direction, -4)
      ..lineTo(0, 0);
    canvas.drawPath(lightHalf, Paint()..color = lightColor);

    final veinPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(20 * direction, -4), veinPaint);

    canvas.restore();
  }

  void _drawFruit(Canvas canvas, double x, double y, Color color) {
    canvas.drawCircle(Offset(x, y), 5.5, Paint()..color = color);
    canvas.drawCircle(Offset(x - 1.5, y - 1.5), 1.8, Paint()..color = Colors.white.withOpacity(0.8));
  }

  void _drawGoldenCrown(Canvas canvas, double cx, double cy) {
    final glow = Paint()
      ..color = const Color(0xFFFBBF24).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cx, cy), 18, glow);

    final crownPath = Path()
      ..moveTo(cx - 20, cy + 8)
      ..lineTo(cx - 20, cy - 8)
      ..lineTo(cx - 10, cy - 2)
      ..lineTo(cx, cy - 14)
      ..lineTo(cx + 10, cy - 2)
      ..lineTo(cx + 20, cy - 8)
      ..lineTo(cx + 20, cy + 8)
      ..close();
    canvas.drawPath(
      crownPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFDE047), Color(0xFFD97706)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(cx - 20, cy - 14, 40, 22)),
    );

    final gemPaint = Paint()..color = const Color(0xFF00E5A3);
    canvas.drawCircle(Offset(cx, cy - 4), 3.2, gemPaint);
    canvas.drawCircle(Offset(cx - 12, cy), 2.2, gemPaint);
    canvas.drawCircle(Offset(cx + 12, cy), 2.2, gemPaint);
  }

  void _drawFallingLeaves(Canvas canvas) {
    for (final leaf in fallingLeaves) {
      canvas.save();
      canvas.translate(leaf.x, leaf.y);
      canvas.rotate(leaf.rotation);
      final p = Paint()..color = leaf.color;
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: leaf.size * 1.5, height: leaf.size * 0.7), p);
      canvas.restore();
    }
  }

  void _drawButterflies(Canvas canvas, double cx, double baseY, bool isGolden) {
    final angle1 = butterflyPhase * math.pi * 2;
    final bx1 = cx - 55 + math.cos(angle1) * 35;
    final by1 = baseY - 70 + math.sin(angle1 * 2) * 22;
    _drawSingleButterfly(canvas, bx1, by1, math.sin(butterflyPhase * 24), isGolden ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8));

    final angle2 = (butterflyPhase + 0.5) * math.pi * 2;
    final bx2 = cx + 55 + math.cos(angle2) * 32;
    final by2 = baseY - 85 + math.sin(angle2 * 2) * 18;
    _drawSingleButterfly(canvas, bx2, by2, math.cos(butterflyPhase * 24), const Color(0xFFF43F5E));
  }

  void _drawSingleButterfly(Canvas canvas, double x, double y, double wingFlap, Color color) {
    final wingWidth = 5.0 * wingFlap.abs().clamp(0.2, 1.0);
    final paint = Paint()..color = color;
    canvas.drawOval(Rect.fromCenter(center: Offset(x - wingWidth * 0.7, y - 2), width: wingWidth, height: 7), paint);
    canvas.drawOval(Rect.fromCenter(center: Offset(x + wingWidth * 0.7, y - 2), width: wingWidth, height: 7), paint);
    canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = const Color(0xFF1E293B));
  }

  void _drawFireflies(Canvas canvas, double cx, double baseY) {
    final fireflyColors = [
      const Color(0xFF4ADE80), // Verde bioluminiscente
      const Color(0xFFFEF08A), // Amarillo eléctrico
      const Color(0xFF38BDF8), // Azul cyan mágico
    ];

    final rnd = math.Random(1337);
    for (int i = 0; i < 14; i++) {
      final baseAngle = (i * math.pi * 2) / 14;
      final dist = 40.0 + rnd.nextDouble() * 55.0;
      final phase = (butterflyPhase * 2 + (i * 0.15)) % 1.0;
      final fx = cx + math.cos(baseAngle + phase * math.pi * 2) * dist;
      final fy = baseY - 75 + math.sin(baseAngle * 2 + phase * math.pi * 2) * 32.0;

      final pulse = (math.sin(butterflyPhase * 16 + i) + 1) * 0.5;
      final color = fireflyColors[i % fireflyColors.length];

      final glow = Paint()
        ..color = color.withOpacity(0.35 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(fx, fy), 8 * pulse, glow);

      final core = Paint()..color = Colors.white.withOpacity(0.9 * pulse);
      canvas.drawCircle(Offset(fx, fy), 2.2, core);
    }
  }

  @override
  bool shouldRepaint(covariant _ForestDioramaPainter oldDelegate) => true;
}
