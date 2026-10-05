import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import 'hogar_weekly_quest_service.dart';

/// Modal BottomSheet interactivo que muestra las 6 misiones semanales,
/// su progreso en tiempo real y el acceso a los comercios aliados.
class HogarWeeklyQuestsModal extends StatelessWidget {
  const HogarWeeklyQuestsModal({
    super.key,
    required this.treeState,
    this.onNavigateToCatalog,
  });

  final WeeklyTreeState treeState;
  final VoidCallback? onNavigateToCatalog;

  static Future<void> show(
    BuildContext context, {
    required WeeklyTreeState treeState,
    VoidCallback? onNavigateToCatalog,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HogarWeeklyQuestsModal(
        treeState: treeState,
        onNavigateToCatalog: onNavigateToCatalog,
      ),
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
            // Asa superior
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

            // Encabezado con estado semanal
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LivoraColors.forest.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: LivoraColors.forest,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Misiones de la Semana',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.deep,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${treeState.weekLabel} · ${treeState.daysLeftInWeek} días restantes',
                        style: TextStyle(
                          fontSize: 12,
                          color: LivoraColors.ink.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: Text(
                    '${treeState.completedQuestsCount}/6 listas',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: LivoraColors.forest,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Indicador de recompensas intermedias y finales
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEAB308).withValues(alpha: 0.12),
                    const Color(0xFF00E5A3).withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEAB308).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Color(0xFFEAB308), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Premios semanales: +0.50 LIVO al llegar a la Etapa 3 y +1.00 LIVO extra con Árbol Dorado.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista scrolleable de las 6 Misiones
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: treeState.quests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final quest = treeState.quests[index];
                  return _QuestItemCard(
                    quest: quest,
                    index: index + 1,
                    onTapCatalog: quest.id == 'quest_6_store_redemption' && !quest.isCompleted
                        ? () {
                            Navigator.pop(context);
                            onNavigateToCatalog?.call();
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestItemCard extends StatelessWidget {
  const _QuestItemCard({
    required this.quest,
    required this.index,
    this.onTapCatalog,
  });

  final WeeklyQuest quest;
  final int index;
  final VoidCallback? onTapCatalog;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: quest.isCompleted
            ? quest.color.withValues(alpha: 0.05)
            : LivoraColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: quest.isCompleted
              ? quest.color.withValues(alpha: 0.35)
              : LivoraColors.border,
          width: 1.1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono con estado
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: quest.isCompleted
                  ? quest.color.withValues(alpha: 0.15)
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              quest.isCompleted ? Icons.check_circle_rounded : quest.icon,
              color: quest.isCompleted ? quest.color : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Texto descriptivo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$index. ${quest.title}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: quest.isCompleted
                              ? LivoraColors.deep
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                    Text(
                      quest.progressLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: quest.isCompleted ? quest.color : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  quest.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: LivoraColors.ink.withValues(alpha: 0.75),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: quest.progressPercent,
                    minHeight: 4.5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      quest.isCompleted ? quest.color : Colors.grey.shade400,
                    ),
                  ),
                ),
                if (onTapCatalog != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onTapCatalog,
                      icon: const Icon(Icons.arrow_outward_rounded, size: 14),
                      label: const Text(
                        'Explorar comercios aliados',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
