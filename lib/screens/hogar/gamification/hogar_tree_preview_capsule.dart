import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import 'hogar_weekly_quest_service.dart';

/// Cápsula compacta y minimalista (altura ~70 dp) para el Dashboard de Inicio.
/// Muestra un mini brote con gradiente, el título de la semana, las misiones completadas y un botón 'Ir a Mi Bosque'.
class HogarTreePreviewCapsule extends StatelessWidget {
  const HogarTreePreviewCapsule({
    super.key,
    required this.treeState,
    required this.onTapOpenForest,
  });

  final WeeklyTreeState treeState;
  final VoidCallback onTapOpenForest;

  @override
  Widget build(BuildContext context) {
    final isGolden = treeState.stage == 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGolden
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : const Color(0xFF00A878).withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isGolden
                ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                : LivoraColors.deep.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTapOpenForest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Mini avatar de estado con gradiente
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isGolden
                          ? const [Color(0xFFFBBF24), Color(0xFFF59E0B)]
                          : const [Color(0xFF00E5A3), Color(0xFF00A878)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isGolden
                          ? Icons.workspace_premium_rounded
                          : (treeState.stage >= 3
                              ? Icons.park_rounded
                              : (treeState.stage == 2
                                  ? Icons.nature_rounded
                                  : Icons.spa_rounded)),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Títulos compactos y barra
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            treeState.stageTitle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isGolden
                                  ? const Color(0xFFB45309)
                                  : LivoraColors.deep,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${treeState.completedQuestsCount}/6 misiones',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: treeState.progressPercent,
                          minHeight: 5,
                          backgroundColor: LivoraColors.paper,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isGolden ? const Color(0xFFF59E0B) : const Color(0xFF00A878),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${treeState.weekLabel} · ${treeState.daysLeftInWeek}d restantes para cerrar ciclo',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: LivoraColors.ink.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Flecha indicadora
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    shape: BoxShape.circle,
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: LivoraColors.forest,
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
