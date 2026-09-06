import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../screens/recolector/kyc_screen.dart';

/// Escudo dinámico reactivo en AppBar para el estado de verificación de identidad (KYC).
class KycStatusShield extends StatelessWidget {
  const KycStatusShield({
    super.key,
    this.overrideStatus,
  });

  /// Estado explícito (útil para pruebas o previews).
  final KycStatus? overrideStatus;

  @override
  Widget build(BuildContext context) {
    final status = overrideStatus ??
        context.select<SessionController, KycStatus>((s) => s.kycStatus);

    final (color, icon, tooltip) = switch (status) {
      KycStatus.unverified => (
          const Color(0xFFE53935),
          Icons.shield_outlined,
          'Identidad no verificada · Toca para verificar',
        ),
      KycStatus.pending => (
          const Color(0xFFD97706),
          Icons.hourglass_top_rounded,
          'Verificación en revisión (24-48h)',
        ),
      KycStatus.approved => (
          LivoraColors.forest,
          Icons.verified_user_rounded,
          'Identidad Verificada',
        ),
      KycStatus.rejected => (
          const Color(0xFFC0392B),
          Icons.gpp_bad_rounded,
          'Verificación rechazada · Toca para reintentar',
        ),
    };

    return IconButton(
      tooltip: tooltip,
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const KycScreen()),
        );
      },
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(
              icon,
              size: 19,
              color: color,
            ),
          ),
          if (status == KycStatus.unverified || status == KycStatus.rejected)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
