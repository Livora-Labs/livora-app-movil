import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_theme.dart';

/// Modal dialog de bienvenida y primeros pasos para el Hogar.
/// Se muestra únicamente la primera vez que un usuario con rol Hogar ingresa a su Dashboard.
class HogarFirstStepsDialog extends StatelessWidget {
  const HogarFirstStepsDialog({super.key});

  static const String prefKey = 'has_seen_hogar_first_steps_v1';

  /// Comprueba en SharedPreferences si ya se mostró la inducción. Si no, la despliega.
  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(prefKey) ?? false;
    if (!hasSeen && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const HogarFirstStepsDialog(),
      );
      await prefs.setBool(prefKey, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: LivoraColors.forest.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: LivoraColors.forest,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Bienvenido a Livora Hogar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: LivoraColors.deep,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Guía de inducción para la gestión y canje de materiales reciclables en tu domicilio:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: LivoraColors.slate,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              // Paso 1
              const _StepRow(
                icon: Icons.location_on_outlined,
                iconColor: LivoraColors.blue,
                stepNumber: '1',
                title: 'Fija tu domicilio',
                description: 'Verifica tu dirección en la barra superior para que los recolectores acudan a tu puerta.',
              ),
              const SizedBox(height: 14),

              // Paso 2
              const _StepRow(
                icon: Icons.recycling_rounded,
                iconColor: LivoraColors.green,
                stepNumber: '2',
                title: 'Separa tus reciclables',
                description: 'Ten a mano botellas PET, latas o cartón limpios y solicita tu recojo en un toque.',
              ),
              const SizedBox(height: 14),

              // Paso 3
              const _StepRow(
                icon: Icons.pin_outlined,
                iconColor: LivoraColors.forest,
                stepNumber: '3',
                title: 'Entrega con tu PIN de seguridad',
                description: 'Al llegar el recolector, dicta tu código de 4 dígitos para autorizar el pesaje y recibir tus LIVOs.',
              ),
              const SizedBox(height: 24),

              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Entendido, comenzar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.iconColor,
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$stepNumber. $title',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: LivoraColors.deep,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: LivoraColors.slate,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
