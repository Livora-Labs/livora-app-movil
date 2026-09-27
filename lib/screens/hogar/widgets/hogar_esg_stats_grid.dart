import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/formats.dart';
import '../../../models/models.dart';
import '../../../widgets/carbon_impact_modal.dart';
import '../../../widgets/common.dart';
import '../../common/wallet_transactions_screen.dart';
import '../collection_history_screen.dart';
import '../recycled_breakdown_screen.dart';

/// Cuadrícula de estadísticas y métricas ESG del Hogar.
/// Muestra prioritariamente el saldo en LIVOs con su equivalencia en Soles en texto secundario.
class HogarEsgStatsGrid extends StatelessWidget {
  const HogarEsgStatsGrid({
    super.key,
    required this.dashboardData,
    required this.requests,
  });

  final Map<String, dynamic> dashboardData;
  final List<CollectionRequest> requests;

  @override
  Widget build(BuildContext context) {
    final esg = dashboardData['esgMetrics'];
    final kgRecycled = (esg?['totalKgRecycled'] as num?)?.toDouble() ?? 0.0;
    final co2Saved = (esg?['co2SavedKg'] as num?)?.toDouble() ?? 0.0;
    final collections = (esg?['totalCollections'] as num?)?.toInt() ?? 0;
    final tokenBal = dashboardData['wallet']?['balance']?.toString() ?? "0.00";
    final balanceVal = double.tryParse(tokenBal) ?? 0.0;
    final treesSaved = (co2Saved / 21.7).toStringAsFixed(1);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        // 1. Saldo de Recompensas (LIVO primero, PEN secundario)
        StatCard(
          icon: Icons.toll,
          label: 'Saldo de Recompensas',
          value: tokenBal,
          unit: 'LIVO',
          subtitle: '≈ S/ ${balanceVal.toStringAsFixed(2)}',
          color: LivoraColors.forest,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WalletTransactionsScreen(),
              ),
            );
          },
        ),

        // 2. Kilogramos reciclados
        StatCard(
          icon: Icons.recycling,
          label: 'Kg reciclados',
          value: fmtNumber(kgRecycled),
          unit: 'kg',
          subtitle: 'Ver desglose',
          color: LivoraColors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecycledBreakdownScreen(
                  totalKg: kgRecycled,
                  requests: requests,
                ),
              ),
            );
          },
        ),

        // 3. Huella ambiental (CO2)
        StatCard(
          icon: Icons.eco_outlined,
          label: 'CO₂ Ahorrado',
          value: fmtNumber(co2Saved),
          unit: 'kg',
          subtitle: '≈ $treesSaved árboles salvados',
          color: LivoraColors.amber,
          onTap: () {
            CarbonImpactModal.show(
              context,
              co2SavedKg: co2Saved,
            );
          },
        ),

        // 4. Historial de Recolecciones
        StatCard(
          icon: Icons.list_alt,
          label: 'Recolecciones',
          value: '$collections',
          subtitle: 'Ver historial',
          color: LivoraColors.cyan,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CollectionHistoryScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
