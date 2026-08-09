import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_theme.dart';

/// Ícono oficial de Livora (SVG en assets/images/livora_icon.svg).
class LivoraLogo extends StatelessWidget {
  const LivoraLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/livora_icon.svg',
      width: size,
      height: size,
    );
  }
}

/// Logo completo con nombre y eslogan, para pantallas de bienvenida.
class LivoraWordmark extends StatelessWidget {
  const LivoraWordmark({super.key, this.iconSize = 110, this.showTagline = true});

  final double iconSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LivoraLogo(size: iconSize),
        const SizedBox(height: 8),
        const Text(
          'LIVORA',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: LivoraColors.ink,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'RECICLAJE VERIFICADO. VALOR REAL.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: LivoraColors.ink.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}
