import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../screens/common/stores_catalog_screen.dart';
import '../../../../screens/common/wallet_transactions_screen.dart';

/// Bloque de acciones rápidas para la billetera (Izipay, Pagar con QR, Catálogo de Tiendas e Historial).
class WalletQuickActions extends StatelessWidget {
  final String? userRole;
  final VoidCallback onIzipayRecharge;
  final VoidCallback onScanAndPay;
  final ValueChanged<String> onCatalogStoreSelected;

  const WalletQuickActions({
    super.key,
    required this.userRole,
    required this.onIzipayRecharge,
    required this.onScanAndPay,
    required this.onCatalogStoreSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isRecolectorOrStore = userRole == 'RECOLECTOR' || userRole == 'TIENDA_RECICLAJE';
    final isHogarOrRecolector = userRole == 'HOGAR' || userRole == 'RECOLECTOR';

    return Column(
      children: [
        if (isRecolectorOrStore) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: LivoraColors.forest,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onIzipayRecharge,
            icon: const Icon(Icons.credit_card_rounded),
            label: Text(
              userRole == 'RECOLECTOR'
                  ? 'Recargar Saldo de Garantía LIVO (Izipay)'
                  : 'Recargar Saldo / Comprar LIVOs (Izipay)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        if (isHogarOrRecolector) ...[
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: LivoraColors.forest,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed: onScanAndPay,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: const Text(
              'Pagar con QR en Tiendas y Bodegas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: LivoraColors.deep,
              side: const BorderSide(color: LivoraColors.deep, width: 1.5),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final scanned = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => const StoresCatalogScreen(),
                ),
              );
              if (scanned != null) {
                onCatalogStoreSelected(scanned);
              }
            },
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text(
              'Explorar Tiendas Cercanas y Descuentos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WalletTransactionsScreen(),
            ),
          ),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text(
            'Ver Historial de Transacciones',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
