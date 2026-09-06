import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Pin central animado para la selección precisa de ubicación en el mini-mapa del Hogar.
/// Se eleva 8dp y proyecta una sombra dinámica cuando el usuario desplaza el mapa.
class CenterPickerPin extends StatelessWidget {
  const CenterPickerPin({
    super.key,
    required this.isDragging,
  });

  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 50,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Sombra inferior en el suelo
              Positioned(
                bottom: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: isDragging ? 14 : 20,
                  height: isDragging ? 5 : 8,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: isDragging ? 0.15 : 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Pin flotante con elevación dinámica
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                bottom: isDragging ? 18 : 10,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: LivoraColors.forest,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: LivoraColors.forest.withValues(alpha: isDragging ? 0.5 : 0.3),
                        blurRadius: isDragging ? 12 : 6,
                        offset: Offset(0, isDragging ? 6 : 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
