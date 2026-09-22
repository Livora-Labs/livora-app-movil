import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/formats.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../screens/recolector/kyc_screen.dart';

/// Botón con ícono de escudo profesional para consultar y gestionar el estado KYC.
class KycShieldButton extends StatelessWidget {
  const KycShieldButton({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    // Solo hogares, recolectores y tiendas requieren verificación KYC y deben ver el escudo.
    // Centros de Acopio, Administradores y Empresas B2B NO manejan verificación personal en la app.
    const allowedRoles = [Roles.hogar, Roles.recolector, Roles.tienda];
    if (user == null || !allowedRoles.contains(user.role)) {
      return const SizedBox.shrink();
    }

    final kycStatus = session.kycStatus;

    IconData icon;
    Color color;
    String tooltip;

    switch (kycStatus) {
      case KycStatus.approved:
        icon = Icons.verified_user_rounded;
        color = const Color(0xFF2E7D32);
        tooltip = 'Identidad Verificada';
        break;
      case KycStatus.pending:
        icon = Icons.shield_outlined;
        color = const Color(0xFFE65100);
        tooltip = 'Verificación en Revisión';
        break;
      case KycStatus.rejected:
        icon = Icons.gpp_bad_rounded;
        color = const Color(0xFFC62828);
        tooltip = 'Verificación Observada';
        break;
      case KycStatus.unverified:
      default:
        icon = Icons.shield_outlined;
        color = LivoraColors.slate;
        tooltip = 'Verificar Identidad';
        break;
    }

    return IconButton(
      tooltip: tooltip,
      icon: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          if (kycStatus == KycStatus.unverified || kycStatus == KycStatus.rejected)
            Positioned(
              right: -1,
              top: 1,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: kycStatus == KycStatus.rejected
                      ? const Color(0xFFC62828)
                      : const Color(0xFFE65100),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      onPressed: () => showKycInfoModal(context),
    );
  }
}

/// Modal profesional e informativo sobre el estado de verificación de identidad KYC.
Future<void> showKycInfoModal(BuildContext context) {
  final session = context.read<SessionController>();
  final kycStatus = session.kycStatus;

  IconData icon;
  Color color;
  String title;
  String subtitle;
  String description;
  bool canAction = false;
  String actionText = '';

  switch (kycStatus) {
    case KycStatus.approved:
      icon = Icons.verified_user_rounded;
      color = const Color(0xFF2E7D32);
      title = 'Identidad Verificada';
      subtitle = 'Cumplimiento normativo acreditado (Ley N° 29733)';
      description =
          'Tu documento de identidad está validado formalmente. Tu cuenta cuenta con habilitación total para acumular recompensas en tokens LIVO, participar en canjes comerciales y operar en la red Stellar / Soroban.';
      break;
    case KycStatus.pending:
      icon = Icons.pending_actions_rounded;
      color = const Color(0xFFE65100);
      title = 'Verificación en Revisión';
      subtitle = 'Auditoría regulatoria en curso';
      description =
          'Tus documentos de identidad han sido remitidos y se encuentran en proceso de validación por el equipo de cumplimiento. Te notificaremos en cuanto el registro sea confirmado.';
      break;
    case KycStatus.rejected:
      icon = Icons.gpp_bad_rounded;
      color = const Color(0xFFC62828);
      title = 'Verificación Observada';
      subtitle = 'Documentación observada o no legible';
      description =
          'No se pudo autenticar tu documento de identidad con los estándares requeridos. Por favor, sube una foto o copia más nítida para reactivar tus beneficios en tokens.';
      canAction = true;
      actionText = 'Actualizar Documento';
      break;
    case KycStatus.unverified:
    default:
      icon = Icons.shield_outlined;
      color = LivoraColors.forest;
      title = 'Verifica tu Identidad';
      subtitle = 'Seguridad y transparencia garantizada';
      description =
          'Para recibir recompensas en tokens LIVO por tus aportes de reciclaje y habilitar transferencias Web3, es necesario validar tu DNI o Carné de Extranjería conforme a ley.';
      canAction = true;
      actionText = 'Validar Identidad Ahora';
      break;
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: LivoraColors.deep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: LivoraColors.ink.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (canAction) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.badge_outlined, size: 20),
              label: Text(
                actionText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KycScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: LivoraColors.slate,
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Entendido'),
            ),
          ] else ...[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text(
                'Entendido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
