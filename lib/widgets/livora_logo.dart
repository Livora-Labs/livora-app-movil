import 'package:flutter/material.dart';

/// Isotipo oficial de Livora (PNG sin fondo) para barras de navegación y encabezados de la UI.
class LivoraLogo extends StatelessWidget {
  const LivoraLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/livora_isotipo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback al ícono clásico por seguridad si no existiera el archivo
        return Image.asset(
          'assets/icon/icon.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      },
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
