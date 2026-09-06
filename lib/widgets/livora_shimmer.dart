import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Efecto Shimmer personalizado de alto rendimiento (60 FPS) sin librerías externas.
/// Utiliza un AnimationController y LinearGradient con interpolación fluida.
class LivoraShimmer extends StatefulWidget {
  const LivoraShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<LivoraShimmer> createState() => _LivoraShimmerState();
}

class _LivoraShimmerState extends State<LivoraShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? const Color(0xFFE6EDE9);
    final highlight = widget.highlightColor ?? const Color(0xFFF7FAF8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final value = _controller.value;
            return LinearGradient(
              begin: const Alignment(-2.0, -0.3),
              end: const Alignment(2.0, 0.3),
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [base, highlight, base],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Contenedor base de bloque para componer esqueletos
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7E3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Esqueleto estándar de tarjeta Livora para listas de solicitudes, lotes, movimientos o canjes.
class LivoraShimmerCard extends StatelessWidget {
  const LivoraShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBox(width: 44, height: 44, borderRadius: 12),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 16),
                      SizedBox(height: 8),
                      ShimmerBox(width: 90, height: 12),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                ShimmerBox(width: 70, height: 26, borderRadius: 14),
              ],
            ),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 110, height: 14),
                ShimmerBox(width: 80, height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de esqueletos Shimmer para estados iniciales de carga diferida
class LivoraShimmerList extends StatelessWidget {
  const LivoraShimmerList({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 80),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LivoraShimmer(
      child: ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        itemBuilder: (context, index) => const LivoraShimmerCard(),
      ),
    );
  }
}
