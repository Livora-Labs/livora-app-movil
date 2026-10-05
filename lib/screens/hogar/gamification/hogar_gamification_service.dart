import 'package:flutter/material.dart';
import '../../../models/models.dart';

/// Modelo de datos para las insignias o medallas de impacto.
class EcoBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final String progressLabel;
  final double progressPercent;

  const EcoBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    required this.progressLabel,
    required this.progressPercent,
  });
}

/// Estado calculado del Árbol Livora y nivel del hogar.
class HogarGrowthLevel {
  final int level;
  final String title;
  final String stageDescription;
  final double currentKg;
  final double targetKg;
  final double progressPercent;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;
  final int streakWeeks;
  final List<EcoBadge> badges;

  const HogarGrowthLevel({
    required this.level,
    required this.title,
    required this.stageDescription,
    required this.currentKg,
    required this.targetKg,
    required this.progressPercent,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
    required this.streakWeeks,
    required this.badges,
  });
}

/// Servicio que calcula los niveles de gamificación, rachas y medallas.
class HogarGamificationService {
  HogarGamificationService._();

  /// Calcula el nivel de árbol y logros a partir de métricas reales.
  static HogarGrowthLevel calculateLevel({
    required double totalKg,
    required int totalCollections,
    required List<CollectionRequest> requests,
  }) {
    final streakWeeks = calculateStreakWeeks(requests);

    // Niveles de crecimiento
    // Nivel 1: Brote Urbano (0 - 15 kg)
    // Nivel 2: Arbusto Verde (15 - 50 kg)
    // Nivel 3: Guardián del Barrio (50 - 150 kg)
    // Nivel 4: Bosque Sagrado (+150 kg)
    int level;
    String title;
    String stageDescription;
    double currentFloorKg;
    double targetKg;
    IconData icon;
    Color primaryColor;
    Color accentColor;

    if (totalKg < 15.0) {
      level = 1;
      title = 'Brote Urbano';
      stageDescription = 'Estás sembrando tu primer impacto en el barrio';
      currentFloorKg = 0.0;
      targetKg = 15.0;
      icon = Icons.spa_rounded;
      primaryColor = const Color(0xFF00A878);
      accentColor = const Color(0xFF00E5A3);
    } else if (totalKg < 50.0) {
      level = 2;
      title = 'Arbusto Verde';
      stageDescription = 'Tu hábito de reciclaje está echando raíces firmes';
      currentFloorKg = 15.0;
      targetKg = 50.0;
      icon = Icons.nature_rounded;
      primaryColor = const Color(0xFF006852);
      accentColor = const Color(0xFF00B4D8);
    } else if (totalKg < 150.0) {
      level = 3;
      title = 'Guardián del Barrio';
      stageDescription = 'Lideras el cambio ecológico en tu comunidad';
      currentFloorKg = 50.0;
      targetKg = 150.0;
      icon = Icons.park_rounded;
      primaryColor = const Color(0xFF004D40);
      accentColor = const Color(0xFFF59E0B);
    } else {
      level = 4;
      title = 'Bosque Sagrado';
      stageDescription = 'Nivel máximo: Inspiras una economía circular viva';
      currentFloorKg = 150.0;
      targetKg = 150.0;
      icon = Icons.forest_rounded;
      primaryColor = const Color(0xFF003B2B);
      accentColor = const Color(0xFFEAB308);
    }

    final span = targetKg - currentFloorKg;
    final progressInLevel = (totalKg - currentFloorKg).clamp(0.0, span);
    final progressPercent = (level == 4) ? 1.0 : (span > 0 ? (progressInLevel / span).clamp(0.0, 1.0) : 1.0);

    // Medallas / Badges
    final badges = [
      EcoBadge(
        id: 'first_step',
        title: 'Primer Paso Verde',
        description: 'Completa tu primera recolección formal de reciclaje.',
        icon: Icons.volunteer_activism_rounded,
        color: const Color(0xFF00A878),
        isUnlocked: totalCollections >= 1,
        progressLabel: '${totalCollections.clamp(0, 1)} / 1 entrega',
        progressPercent: (totalCollections >= 1) ? 1.0 : 0.0,
      ),
      EcoBadge(
        id: 'ten_kilos',
        title: 'Club de los 10 Kg',
        description: 'Recicla tus primeros 10 kg de materiales valorizables.',
        icon: Icons.scale_rounded,
        color: const Color(0xFF0077B6),
        isUnlocked: totalKg >= 10.0,
        progressLabel: '${totalKg.clamp(0.0, 10.0).toStringAsFixed(1)} / 10 kg',
        progressPercent: (totalKg / 10.0).clamp(0.0, 1.0),
      ),
      EcoBadge(
        id: 'streak_master',
        title: 'Racha Ecológica',
        description: 'Mantén una racha de al menos 2 semanas reciclando.',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFEF4444),
        isUnlocked: streakWeeks >= 2,
        progressLabel: '${streakWeeks.clamp(0, 2)} / 2 semanas',
        progressPercent: (streakWeeks / 2.0).clamp(0.0, 1.0),
      ),
      EcoBadge(
        id: 'planet_hero',
        title: 'Protector de Bosques',
        description: 'Recicla más de 50 kg y evita decenas de kg de CO₂.',
        icon: Icons.shield_rounded,
        color: const Color(0xFFEAB308),
        isUnlocked: totalKg >= 50.0,
        progressLabel: '${totalKg.clamp(0.0, 50.0).toStringAsFixed(1)} / 50 kg',
        progressPercent: (totalKg / 50.0).clamp(0.0, 1.0),
      ),
    ];

    return HogarGrowthLevel(
      level: level,
      title: title,
      stageDescription: stageDescription,
      currentKg: totalKg,
      targetKg: targetKg,
      progressPercent: progressPercent,
      icon: icon,
      primaryColor: primaryColor,
      accentColor: accentColor,
      streakWeeks: streakWeeks,
      badges: badges,
    );
  }

  /// Calcula la racha semanal consecutiva en semanas naturales basadas en completedAt/createdAt.
  static int calculateStreakWeeks(List<CollectionRequest> requests) {
    final completed = requests
        .where((r) => r.status == 'COMPLETED' && r.createdAt != null)
        .map((r) => r.createdAt!)
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Más recientes primero

    if (completed.isEmpty) return 0;

    final now = DateTime.now();
    final latest = completed.first;
    final diffDays = now.difference(latest).inDays;

    // Si la última entrega fue hace más de 14 días, la racha expiró
    if (diffDays > 14) return 0;

    int streak = 1;
    DateTime currentRef = latest;

    for (int i = 1; i < completed.length; i++) {
      final prev = completed[i];
      final daysBetween = currentRef.difference(prev).inDays;
      if (daysBetween >= 5 && daysBetween <= 14) {
        streak++;
        currentRef = prev;
      } else if (daysBetween < 5) {
        // Misma semana o días cercanos, suma a la actividad pero no salta de semana
        continue;
      } else {
        break;
      }
    }

    return streak;
  }
}
