import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// Barra de accesos directos rápidos para el comerciante aliado.
class StoreQuickActionsBar extends StatelessWidget {
  const StoreQuickActionsBar({
    super.key,
    required this.onCobrarTap,
    required this.onCartelQrTap,
    required this.onCashOutTap,
    required this.onHistorialTap,
  });

  final VoidCallback onCobrarTap;
  final VoidCallback onCartelQrTap;
  final VoidCallback onCashOutTap;
  final VoidCallback onHistorialTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionItem(
          label: 'Cobrar POS',
          icon: Icons.qr_code_scanner_rounded,
          color: LivoraColors.forest,
          onTap: onCobrarTap,
        ),
        const SizedBox(width: 8),
        _ActionItem(
          label: 'Cartel QR',
          icon: Icons.storefront_rounded,
          color: LivoraColors.blue,
          onTap: onCartelQrTap,
        ),
        const SizedBox(width: 8),
        _ActionItem(
          label: 'Retirar CCI',
          icon: Icons.account_balance_rounded,
          color: const Color(0xFFD97706),
          onTap: onCashOutTap,
        ),
        const SizedBox(width: 8),
        _ActionItem(
          label: 'Historial',
          icon: Icons.receipt_long_rounded,
          color: LivoraColors.slate,
          onTap: onHistorialTap,
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LivoraColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LivoraColors.deep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
