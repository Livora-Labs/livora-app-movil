import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Micro-widget para acciones críticas de la cuenta (Cerrar sesión y Eliminar cuenta).
class ProfileAccountDangerZone extends StatelessWidget {
  const ProfileAccountDangerZone({
    super.key,
    required this.onLogout,
    required this.onDeleteAccount,
    required this.onChangePassword,
  });

  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Seguridad de la Cuenta',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade300),
            ),
            icon: const Icon(Icons.lock_reset_rounded, size: 20),
            label: const Text('Cambiar contraseña'),
            onPressed: onChangePassword,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: Colors.grey.shade800,
              side: BorderSide(color: Colors.grey.shade300),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Cerrar sesión'),
            onPressed: onLogout,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: LivoraColors.coral,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Eliminar cuenta permanentemente'),
            onPressed: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}
