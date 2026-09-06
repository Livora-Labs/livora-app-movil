import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/formats.dart';

/// Modal BottomSheet estilizado para visualizar la huella de carbono evitada
/// y sus equivalencias de impacto positivo en el medio ambiente.
class CarbonImpactModal extends StatelessWidget {
  const CarbonImpactModal({
    super.key,
    required this.co2SavedKg,
  });

  final double co2SavedKg;

  static Future<void> show(BuildContext context, {required double co2SavedKg}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CarbonImpactModal(co2SavedKg: co2SavedKg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final treesSaved = (co2SavedKg / 21.7).toStringAsFixed(1);
    final kmSaved = (co2SavedKg * 4.1).toStringAsFixed(0);
    final bottlesEquivalent = (co2SavedKg * 18).toStringAsFixed(0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    color: LivoraColors.green.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: LivoraColors.forest,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impacto Ambiental Positivo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Medición certificada de emisiones evitadas',
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
            const SizedBox(height: 18),

            // Tarjeta Principal CO2 Evitado
            Container(
              padding: const EdgeInsets.all(18),
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
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emisiones Evitadas a la Atmósfera',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        fmtNumber(co2SavedKg),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Kg de CO₂eq',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu reciclaje previene la degradación en vertederos y la extracción de materia virgen.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'EQUIVALENCIAS EN EL MUNDO REAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: LivoraColors.slate,
              ),
            ),
            const SizedBox(height: 10),

            // Grid de 3 métricas
            Row(
              children: [
                Expanded(
                  child: _ImpactItem(
                    icon: Icons.park_outlined,
                    color: LivoraColors.green,
                    title: '≈ $treesSaved',
                    subtitle: 'Árboles absorbiendo CO₂',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ImpactItem(
                    icon: Icons.directions_car_outlined,
                    color: LivoraColors.blue,
                    title: '≈ $kmSaved km',
                    subtitle: 'No conducidos en auto',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ImpactItem(
                    icon: Icons.local_drink_outlined,
                    color: LivoraColors.cyan,
                    title: '≈ $bottlesEquivalent',
                    subtitle: 'Botellas PET recuperadas',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Entendido',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactItem extends StatelessWidget {
  const _ImpactItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LivoraColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LivoraColors.ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: LivoraColors.deep,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              color: LivoraColors.ink.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
