import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/stellar.dart';
import '../../../../widgets/common.dart';

/// Tarjeta de cabecera de la billetera con degradado oficial, saldo, conversión a PEN y clave pública.
class WalletBalanceHeader extends StatelessWidget {
  final String? balance;
  final bool isLoading;
  final String? userRole;
  final String? walletAddress;
  final VoidCallback onRefresh;

  const WalletBalanceHeader({
    super.key,
    required this.balance,
    required this.isLoading,
    required this.userRole,
    required this.walletAddress,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final balanceVal = double.tryParse(balance ?? '0') ?? 0.0;
    final isHogar = userRole == 'HOGAR';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LivoraColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isHogar ? 'Mis Puntos de Recompensa LIVO' : 'Saldo de LIVOs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: isLoading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onRefresh();
                      },
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          isLoading && balance == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : Text(
                  balance ?? '0.00',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
          const SizedBox(height: 2),
          Text(
            '≈ S/ ${balanceVal.toStringAsFixed(2)} PEN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isHogar
                ? 'Recompensa ecológica familiar (1 LIVO = S/ 1.00 PEN)'
                : 'LIVO · Billetera de Incentivos (1 LIVO = S/ 1.00)',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          if (walletAddress != null) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                await HapticFeedback.lightImpact();
                await Clipboard.setData(ClipboardData(text: walletAddress!));
                if (context.mounted) {
                  showAppSnack(context, 'Dirección pública copiada');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        walletAddress!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  final opened = await Stellar.openAccountInExplorer(walletAddress!);
                  if (!opened && context.mounted) {
                    showAppSnack(
                      context,
                      'No se pudo abrir el explorador de transacciones',
                      error: true,
                    );
                  }
                },
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text(
                  'Ver en el explorador digital',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
