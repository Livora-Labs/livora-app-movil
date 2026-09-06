import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Pantalla interactiva que desglosa los kilogramos reciclados por material.
class RecycledBreakdownScreen extends StatelessWidget {
  const RecycledBreakdownScreen({
    super.key,
    required this.totalKg,
    required this.requests,
  });

  final double totalKg;
  final List<CollectionRequest> requests;

  Map<String, double> get _materialTotals {
    final map = <String, double>{};
    for (final req in requests) {
      if (req.status == 'COMPLETED') {
        final weights = req.actualWeights ?? req.itemsEstimated;
        weights.forEach((mat, kg) {
          final normalized = mat.toUpperCase();
          map[normalized] = (map[normalized] ?? 0) + kg;
        });
      }
    }
    return map;
  }

  Color _colorFor(String material) => switch (material.toUpperCase()) {
        'PET' || 'PLASTICO' => LivoraColors.blue,
        'VIDRIO' => LivoraColors.forest,
        'CARTON' || 'PAPEL' => LivoraColors.amber,
        'ALUMINIO' || 'METAL' => LivoraColors.cyan,
        _ => LivoraColors.green,
      };

  IconData _iconFor(String material) => switch (material.toUpperCase()) {
        'PET' || 'PLASTICO' => Icons.local_drink_outlined,
        'VIDRIO' => Icons.wine_bar_outlined,
        'CARTON' || 'PAPEL' => Icons.inventory_2_outlined,
        'ALUMINIO' || 'METAL' => Icons.hardware_outlined,
        _ => Icons.recycling_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final materials = _materialTotals;
    final computedTotal = materials.values.fold<double>(0.0, (sum, val) => sum + val);
    final displayTotal = computedTotal > 0 ? computedTotal : totalKg;
    final completedRequests =
        requests.where((r) => r.status == 'COMPLETED').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impacto del Reciclaje'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [LivoraColors.forest, LivoraColors.deep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: LivoraColors.forest.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.recycling_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Acumulado',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            'Material Recuperado',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      fmtNumber(displayTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Kg totales',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.park_outlined, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '≈ ${(displayTotal * 2.4 / 21.7).toStringAsFixed(1)} árboles preservados',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(text: 'Desglose por Material'),
          if (materials.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Aún no hay registros de materiales reciclados.',
                    style: TextStyle(color: LivoraColors.ink),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: materials.entries.map((entry) {
                    final percentage = displayTotal > 0
                        ? (entry.value / displayTotal) * 100
                        : 0.0;
                    final color = _colorFor(entry.key);
                    final icon = _iconFor(entry.key);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, color: color, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  materialLabel(entry.key),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: LivoraColors.deep,
                                  ),
                                ),
                              ),
                              Text(
                                '${fmtKg(entry.value)} (${percentage.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: displayTotal > 0 ? (entry.value / displayTotal) : 0,
                              minHeight: 8,
                              backgroundColor: color.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const SectionTitle(text: 'Historial de Entregas'),
          if (completedRequests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No hay entregas completadas todavía.',
                    style: TextStyle(color: LivoraColors.ink),
                  ),
                ),
              ),
            )
          else
            ...completedRequests.map((req) {
              final weights = req.actualWeights ?? req.itemsEstimated;
              final reqTotal = weights.values.fold<double>(0.0, (s, w) => s + w);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: LivoraColors.paper,
                    child: Icon(Icons.check_circle_rounded, color: LivoraColors.green),
                  ),
                  title: Text(
                    materialsSummary(weights),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: LivoraColors.deep,
                    ),
                  ),
                  subtitle: Text(
                    '${fmtDate(req.createdAt)} · ${req.collectorName ?? req.collectorEmail ?? "Recolector"}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: Text(
                    fmtKg(reqTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: LivoraColors.forest,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
