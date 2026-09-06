import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../screens/common/qr_scanner_view.dart';
import '../services/livora_api.dart';

/// BottomSheet que muestra los comercios aliados cercanos y permite iniciar
/// el flujo de canje de EcoTokens vía QR.
class AlliedStoresSheet extends StatefulWidget {
  const AlliedStoresSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AlliedStoresSheet(),
    );
  }

  @override
  State<AlliedStoresSheet> createState() => _AlliedStoresSheetState();
}

class _AlliedStoresSheetState extends State<AlliedStoresSheet> {
  List<Map<String, dynamic>>? _stores;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      final stores = await context.read<LivoraApi>().fetchAlliedStores();
      if (mounted) {
        setState(() {
          _stores = stores;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: LivoraColors.ink.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LivoraColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: LivoraColors.blue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiendas y Comercios Aliados',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Canjea tus EcoTokens (1 ECO = S/ 1.00 PEN)',
                        style: TextStyle(
                          fontSize: 12,
                          color: LivoraColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _stores == null || _stores!.isEmpty
                      ? Center(
                          child: Text(
                            'No se encontraron comercios aliados registrados.',
                            style: TextStyle(
                              fontSize: 13,
                              color: LivoraColors.ink.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _stores!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final store = _stores![index];
                            final name = store['name']?.toString() ?? 'Comercio Aliado';
                            final category = store['category']?.toString() ?? 'General';
                            final address = store['address']?.toString() ?? 'Lima, Perú';
                            final discount = store['discount']?.toString() ?? 'Canje disponible';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: LivoraColors.paper,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: LivoraColors.ink.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                                    child: const Icon(
                                      Icons.store_mall_directory_outlined,
                                      color: LivoraColors.forest,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: LivoraColors.deep,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          address,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: LivoraColors.ink.withValues(alpha: 0.75),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: LivoraColors.green.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$category · $discount',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: LivoraColors.forest,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QRScannerView()),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Escanear QR en Comercio',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
