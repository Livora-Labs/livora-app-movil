import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ConfettiShape { leaf, circle, star, coin }

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double rotation;
  double rotationSpeed;
  Color color;
  ConfettiShape shape;
  double opacity;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.shape,
    required this.opacity,
  });
}

/// Canvas interactivo de partículas ecológicas flotantes y confeti sin dependencias pesadas.
class EcoConfettiOverlay extends StatefulWidget {
  const EcoConfettiOverlay({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 4),
    this.autoStart = false,
  });

  final Widget child;
  final Duration duration;
  final bool autoStart;

  @override
  State<EcoConfettiOverlay> createState() => EcoConfettiOverlayState();
}

class EcoConfettiOverlayState extends State<EcoConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();
  bool _isPlaying = false;

  final List<Color> _palette = const [
    Color(0xFF00A878), // Verde Livora
    Color(0xFF00E5A3), // Menta
    Color(0xFF00B4D8), // Celeste
    Color(0xFFEAB308), // Dorado / LIVO
    Color(0xFFF59E0B), // Ámbar
    Color(0xFF10B981), // Esmeralda
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(_updateParticles)
     ..addStatusListener((status) {
       if (status == AnimationStatus.completed) {
         setState(() {
           _isPlaying = false;
           _particles.clear();
         });
       }
     });

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => play());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void play() {
    _particles.clear();
    // Generar 60 partículas optimizadas
    for (int i = 0; i < 60; i++) {
      const shapes = ConfettiShape.values;
      _particles.add(
        ConfettiParticle(
          x: 0.1 + _random.nextDouble() * 0.8, // 10% a 90% del ancho
          y: -0.1 - _random.nextDouble() * 0.2, // arriba de la pantalla
          vx: (_random.nextDouble() - 0.5) * 0.008,
          vy: 0.003 + _random.nextDouble() * 0.007,
          size: 6.0 + _random.nextDouble() * 8.0,
          rotation: _random.nextDouble() * 2 * math.pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.15,
          color: _palette[_random.nextInt(_palette.length)],
          shape: shapes[_random.nextInt(shapes.length)],
          opacity: 1.0,
        ),
      );
    }
    setState(() => _isPlaying = true);
    _controller.forward(from: 0.0);
  }

  void _updateParticles() {
    if (!_isPlaying) return;
    for (final p in _particles) {
      p.x += p.vx + math.sin(p.rotation) * 0.001;
      p.y += p.vy;
      p.rotation += p.rotationSpeed;
      if (_controller.value > 0.7) {
        p.opacity = ((1.0 - _controller.value) / 0.3).clamp(0.0, 1.0);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isPlaying)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(particles: _particles),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      if (p.opacity <= 0) continue;
      paint.color = p.color.withOpacity(p.opacity);

      final px = p.x * size.width;
      final py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case ConfettiShape.leaf:
          // Dibujar forma de hoja estilizada
          final path = Path()
            ..moveTo(0, -p.size)
            ..quadraticBezierTo(p.size * 0.8, 0, 0, p.size)
            ..quadraticBezierTo(-p.size * 0.8, 0, 0, -p.size);
          canvas.drawPath(path, paint);
          break;
        case ConfettiShape.circle:
        case ConfettiShape.coin:
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
          break;
        case ConfettiShape.star:
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          );
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
