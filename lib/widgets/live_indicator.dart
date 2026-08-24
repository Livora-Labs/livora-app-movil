import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../services/livora_realtime.dart';

/// Punto que indica si la conexión en tiempo real está activa.
///
/// Cuando está verde, la pantalla se actualiza sola; si se cae, el usuario ve
/// que debe refrescar a mano en vez de creer que no hay novedades.
class LiveIndicator extends StatelessWidget {
  const LiveIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<LivoraRealtime>().isConnected;
    return Tooltip(
      message: connected
          ? 'En vivo: las novedades llegan solas'
          : 'Sin conexión en vivo: desliza para actualizar',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected
                  ? LivoraColors.mint
                  : LivoraColors.ink.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
