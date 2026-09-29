import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_theme.dart';
import '../kyc_screen.dart';

/// Modal dialog de bienvenida y primeros pasos para el Recolector.
/// Se muestra únicamente la primera vez que un usuario con rol Recolector ingresa al Radar.
class CollectorFirstStepsDialog extends StatelessWidget {
  const CollectorFirstStepsDialog({super.key});

  static const String prefKey = 'has_seen_recolector_first_steps_v1';

  /// Comprueba en SharedPreferences si ya se mostró la inducción. Si no, la despliega.
  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(prefKey) ?? false;
    if (!hasSeen && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CollectorFirstStepsDialog(),
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
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
                    Icons.local_shipping_rounded,
                    color: LivoraColors.forest,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Bienvenido a Livora Recolector',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: LivoraColors.deep,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Guía de inducción operativa para generar ingresos recolectando y entregando en acopios:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: LivoraColors.slate,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              // Paso 1: KYC
              const _StepRow(
                icon: Icons.badge_outlined,
                iconColor: LivoraColors.forest,
                stepNumber: '1',
                title: 'Valida tu Identidad y Vehículo (KYC)',
                description:
                    'Registra tu DNI/CE y vehículo (triciclo o motofurgón) conforme a la Ley N° 29733 para poder aceptar pedidos.',
              ),
              const SizedBox(height: 14),

              // Paso 2: Radar y Recojo
              const _StepRow(
                icon: Icons.radar_rounded,
                iconColor: LivoraColors.blue,
                stepNumber: '2',
                title: 'Explora el Radar y Acepta',
                description:
                    'Revisa solicitudes en tu zona con filtro de radio GPS. Conduce al domicilio y valida el recojo con el PIN de 4 dígitos.',
              ),
              const SizedBox(height: 14),

              // Paso 3: Acopio y Canje
              const _StepRow(
                icon: Icons.warehouse_rounded,
                iconColor: LivoraColors.green,
                stepNumber: '3',
                title: 'Acopia y Canjea en Tiendas',
                description:
                    'Despacha tus lotes en centros de acopio autorizados y canjea tus tokens LIVO en la red de comercios y bodegas asociadas.',
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined, size: 20),
                label: const Text(
                  'Completar Verificación (KYC)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const KycScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: LivoraColors.slate,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Explorar el radar primero',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
          width: 38,
          height: 38,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: LivoraColors.mint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Paso $stepNumber',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: LivoraColors.deep,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: LivoraColors.ink,
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
