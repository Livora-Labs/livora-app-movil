import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import 'living_tree_canvas.dart';
import 'hogar_weekly_quest_service.dart';
import 'hogar_weekly_quests_modal.dart';
import 'hogar_grove_history_modal.dart';

/// Tarjeta Héroe viva del Árbol Semanal de Livora con animación orgánica de viento,
/// indicador de días restantes, acceso a misiones y barra segmentada de 4 etapas.
class HogarAnimatedTreeCard extends StatelessWidget {
  const HogarAnimatedTreeCard({
    super.key,
    required this.treeState,
    this.onNavigateToCatalog,
  });

  final WeeklyTreeState treeState;
  final VoidCallback? onNavigateToCatalog;

  @override
  Widget build(BuildContext context) {
    final isGolden = treeState.stage == 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isGolden
              ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
              : const Color(0xFF00A878).withValues(alpha: 0.22),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: isGolden
                ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                : LivoraColors.deep.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Barra Superior: Semana + Días restantes + Botón Arboleda Histórica
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: LivoraColors.forest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: LivoraColors.forest),
                      const SizedBox(width: 5),
                      Text(
                        treeState.weekLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: LivoraColors.forest,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${treeState.daysLeftInWeek}d restantes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: LivoraColors.ink.withValues(alpha: 0.65),
                  ),
                ),
                const Spacer(),
                // Botón Arboleda Histórica
                IconButton(
                  tooltip: 'Ver Arboleda Histórica',
                  style: IconButton.styleFrom(
                    backgroundColor: LivoraColors.paper,
                    padding: const EdgeInsets.all(6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.forest_rounded, size: 18, color: LivoraColors.deep),
                  onPressed: () => HogarGroveHistoryModal.show(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 2. Escenario Vivo del Árbol con viento interactivo
            Stack(
              alignment: Alignment.center,
              children: [
                LivingTreeCanvas(
                  stage: treeState.stage,
                  height: 155,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      side: const BorderSide(color: LivoraColors.forest, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => HogarWeeklyQuestsModal.show(
                      context,
                      treeState: treeState,
                      onNavigateToCatalog: onNavigateToCatalog,
                    ),
                    icon: const Icon(Icons.checklist_rounded, size: 16, color: LivoraColors.forest),
                    label: Text(
                      '${treeState.completedQuestsCount}/6 Misiones',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.forest,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 3. Título de Etapa y Subtítulo inspirador
            Text(
              treeState.stageTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isGolden ? const Color(0xFFB45309) : LivoraColors.deep,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              treeState.stageSubtitle,
              style: TextStyle(
                fontSize: 12,
                color: LivoraColors.ink.withValues(alpha: 0.75),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),

            // 4. Barra Segmentada en 4 Etapas
            _SegmentedStageProgress(
              currentStage: treeState.stage,
              completedCount: treeState.completedQuestsCount,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedStageProgress extends StatelessWidget {
  const _SegmentedStageProgress({
    required this.currentStage,
    required this.completedCount,
  });

  final int currentStage;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    const stages = [
      _StageInfo('Semilla', 0, Icons.spa_rounded),
      _StageInfo('Brote', 2, Icons.nature_rounded),
      _StageInfo('Joven (+0.5 L)', 4, Icons.park_rounded),
      _StageInfo('Dorado (+1.0 L)', 6, Icons.workspace_premium_rounded),
    ];

    return Column(
      children: [
        // Línea de nodos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(stages.length, (index) {
            final stage = stages[index];
            final isReached = completedCount >= stage.requiredQuests;
            final isCurrent = currentStage == (index + 1);

            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isReached
                          ? (index == 3 ? const Color(0xFFF59E0B) : const Color(0xFF00A878))
                          : Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? (index == 3 ? const Color(0xFFB45309) : LivoraColors.deep)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      stage.icon,
                      size: 15,
                      color: isReached ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                  if (index < stages.length - 1)
                    Expanded(
                      child: Container(
                        height: 4,
                        color: completedCount > stages[index].requiredQuests
                            ? const Color(0xFF00A878)
                            : Colors.grey.shade200,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        // Etiquetas inferiores
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stages.map((s) {
            final isReached = completedCount >= s.requiredQuests;
            return Text(
              s.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isReached ? FontWeight.w700 : FontWeight.w500,
                color: isReached ? LivoraColors.deep : Colors.grey.shade600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StageInfo {
  final String name;
  final int requiredQuests;
  final IconData icon;

  const _StageInfo(this.name, this.requiredQuests, this.icon);
}
