import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

/// Logotipo oficial de Livora, para pantallas de bienvenida.
class LivoraWordmark extends StatelessWidget {
  const LivoraWordmark({super.key, this.width = 300});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/livora-logotipo.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
