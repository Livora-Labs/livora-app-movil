import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import 'hogar_weekly_quest_service.dart';

/// Modal BottomSheet que expone la Arboleda Histórica del Hogar
/// (todos los árboles maduros completados en semanas pasadas).
class HogarGroveHistoryModal extends StatelessWidget {
  const HogarGroveHistoryModal({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HogarGroveHistoryModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Asa
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

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006852).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.forest_rounded,
                    color: Color(0xFF006852),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu Arboleda Histórica',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Registro de todos tus árboles completados semana a semana',
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
            const SizedBox(height: 20),

            // Lista de Árboles
            FutureBuilder<List<ArchivedTreeRecord>>(
              future: HogarWeeklyQuestService.getGroveHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final grove = snapshot.data ?? [];
                if (grove.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: LivoraColors.paper,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: LivoraColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.eco_outlined,
                          size: 44,
                          color: LivoraColors.ink.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tu arboleda está comenzando',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Completa las misiones de esta semana para cultivar tu primer árbol permanente en esta colección.',
                          style: TextStyle(
                            fontSize: 12,
                            color: LivoraColors.ink.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: grove.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final tree = grove[index];
                      final isGolden = tree.stageReached == 4;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isGolden
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.06)
                              : LivoraColors.paper,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isGolden
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                                : LivoraColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isGolden
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                    : const Color(0xFF00A878).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isGolden ? Icons.workspace_premium_rounded : Icons.park_rounded,
                                color: isGolden ? const Color(0xFFF59E0B) : const Color(0xFF00A878),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        tree.stageTitle,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: LivoraColors.deep,
                                        ),
                                      ),
                                      if (isGolden) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'DORADO',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${tree.weekLabel} · ${tree.questsCompleted}/6 misiones',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: LivoraColors.ink.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${tree.totalKg.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.forest,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
