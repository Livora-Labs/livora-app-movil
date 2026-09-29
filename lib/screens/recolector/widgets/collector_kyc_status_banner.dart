import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../../models/models.dart';
import '../kyc_screen.dart';

/// Banner de estado y acceso directo al KYC para la pantalla de Solicitudes Disponibles del Recolector.
/// Se muestra en la parte superior de la lista deslizable cuando el recolector no está verificado.
class CollectorKycStatusBanner extends StatelessWidget {
  const CollectorKycStatusBanner({
    super.key,
    required this.kycStatus,
  });

  final KycStatus kycStatus;

  @override
  Widget build(BuildContext context) {
    if (kycStatus == KycStatus.approved) {
      return const SizedBox.shrink();
    }

    final Color bgColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;
    final String title;
    final String subtitle;
    final String actionLabel;

    switch (kycStatus) {
      case KycStatus.pending:
        bgColor = const Color(0xFFFFF8E1);
        borderColor = const Color(0xFFFFD54F);
        iconColor = const Color(0xFFF57F17);
        icon = Icons.hourglass_top_rounded;
        title = 'Documentación en Auditoría';
        subtitle = 'Tus documentos vehiculares y DNI están en revisión por el equipo de cumplimiento.';
        actionLabel = 'Ver Estado';
        break;
      case KycStatus.rejected:
        bgColor = const Color(0xFFFFEBEE);
        borderColor = const Color(0xFFEF9A9A);
        iconColor = const Color(0xFFC62828);
        icon = Icons.gpp_bad_rounded;
        title = 'Documentación Observada';
        subtitle = 'Se detectaron observaciones en tu DNI o datos vehiculares. Toca para actualizar y subsanar.';
        actionLabel = 'Corregir KYC';
        break;
      case KycStatus.unverified:
      default:
        bgColor = LivoraColors.mint.withValues(alpha: 0.18);
        borderColor = LivoraColors.forest.withValues(alpha: 0.35);
        iconColor = LivoraColors.forest;
        icon = Icons.shield_outlined;
        title = 'Verificación Requerida';
        subtitle = 'Completa tu validación de DNI y vehículo para poder aceptar solicitudes y acumular tokens LIVO.';
        actionLabel = 'Verificar Ahora';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: iconColor == LivoraColors.forest ? LivoraColors.deep : iconColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
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
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 34,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined, size: 15),
                label: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const KycScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
