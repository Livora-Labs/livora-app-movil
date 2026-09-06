import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../models/models.dart';
import '../screens/recolector/kyc_screen.dart';

/// Modal BottomSheet explicativo cuando se intenta aceptar una orden sin verificación KYC aprobada.
class KycRequiredBottomSheet extends StatelessWidget {
  const KycRequiredBottomSheet({
    super.key,
    required this.kycStatus,
  });

  final KycStatus kycStatus;

  static Future<void> show(
    BuildContext context, {
    required KycStatus kycStatus,
  }) async {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => KycRequiredBottomSheet(kycStatus: kycStatus),
    );
  }

  (IconData, Color, String, String, String) _sheetData() {
    switch (kycStatus) {
      case KycStatus.unverified:
        return (
          Icons.shield_outlined,
          const Color(0xFFD97706),
          'Verificación de Identidad Requerida',
          'Por seguridad de los hogares y cumplimiento normativo (Ley N.° 29733), todo recolector debe validar su identidad con DNI o Carné de Extranjería antes de aceptar órdenes y bloquear garantías escrow.',
          'Completar Verificación',
        );
      case KycStatus.pending:
        return (
          Icons.hourglass_top_rounded,
          const Color(0xFFD97706),
          'Verificación en Revisión',
          'Tus documentos fueron recibidos y nuestro equipo los está auditando (tiempo estimado: 24 a 48 horas hábiles). Tan pronto sean aprobados podrás aceptar solicitudes activas.',
          'Ver Estado de Documentos',
        );
      case KycStatus.rejected:
        return (
          Icons.gpp_bad_rounded,
          const Color(0xFFC0392B),
          'Verificación Rechazada',
          'El documento subido anteriormente no cumplió con los estándares de legibilidad o vigencia requeridos. Por favor sube un nuevo archivo o fotografía nítida.',
          'Reintentar Verificación',
        );
      case KycStatus.approved:
        return (
          Icons.verified_user_rounded,
          LivoraColors.forest,
          'Cuenta Verificada',
          'Tu cuenta está completamente acreditada para realizar recolecciones.',
          'Ver Credencial',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, description, ctaLabel) = _sheetData();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tirador táctil (Drag Handle)
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Icono Héroe
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 42),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: LivoraColors.deep,
              ),
            ),
            const SizedBox(height: 10),

            // Descripción Legal y Operativa
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: LivoraColors.slate,
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta de Beneficios y Seguridad
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LivoraColors.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LivoraColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined, size: 20, color: LivoraColors.forest),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'La verificación activa tu reputación, insignia oficial en Stellar y acceso al monedero de EcoTokens.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: LivoraColors.deep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón Principal
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const KycScreen()),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                ctaLabel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            // Botón Secundario
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: const Text('Continuar explorando el radar'),
            ),
          ],
        ),
      ),
    );
  }
}
