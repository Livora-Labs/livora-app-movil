import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/models.dart';

/// Representa una misión semanal evaluable.
class WeeklyQuest {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isCompleted;
  final String progressLabel;
  final double progressPercent;

  const WeeklyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isCompleted,
    required this.progressLabel,
    required this.progressPercent,
  });
}

/// Estado calculado del Árbol Semanal.
class WeeklyTreeState {
  final int stage; // 1: Semilla, 2: Brote, 3: Árbol Joven, 4: Árbol Dorado
  final String stageTitle;
  final String stageSubtitle;
  final List<WeeklyQuest> quests;
  final int completedQuestsCount;
  final double progressPercent;
  final bool claimedStage3Reward; // +0.50 LIVO
  final bool claimedStage4Reward; // +1.00 LIVO
  final int daysLeftInWeek;
  final String weekLabel;

  const WeeklyTreeState({
    required this.stage,
    required this.stageTitle,
    required this.stageSubtitle,
    required this.quests,
    required this.completedQuestsCount,
    required this.progressPercent,
    required this.claimedStage3Reward,
    required this.claimedStage4Reward,
    required this.daysLeftInWeek,
    required this.weekLabel,
  });

  factory WeeklyTreeState.fromBackendJson(Map<String, dynamic> json) {
    final questsRaw = json['quests'] as List? ?? const [];
    final quests = <WeeklyQuest>[];

    const iconMap = <String, IconData>{
      'quest_1_completed_batch': Icons.verified_rounded,
      'quest_2_clean_delivery': Icons.star_rounded,
      'quest_3_volume': Icons.scale_rounded,
      'quest_4_multi_material': Icons.category_rounded,
      'quest_5_high_impact_material': Icons.shield_rounded,
      'quest_6_store_redemption': Icons.storefront_rounded,
    };

    const colorMap = <String, Color>{
      'quest_1_completed_batch': Color(0xFF00A878),
      'quest_2_clean_delivery': Color(0xFF00B4D8),
      'quest_3_volume': Color(0xFF0077B6),
      'quest_4_multi_material': Color(0xFFF59E0B),
      'quest_5_high_impact_material': Color(0xFF8B5CF6),
      'quest_6_store_redemption': Color(0xFFEAB308),
    };

    for (final q in questsRaw) {
      if (q is Map<String, dynamic>) {
        final id = q['id'] as String? ?? '';
        quests.add(
          WeeklyQuest(
            id: id,
            title: q['title'] as String? ?? '',
            description: q['description'] as String? ?? '',
            icon: iconMap[id] ?? Icons.eco_rounded,
            color: colorMap[id] ?? const Color(0xFF00A878),
            isCompleted: q['isCompleted'] as bool? ?? false,
            progressLabel: q['progressLabel'] as String? ?? '',
            progressPercent: (q['progressPercent'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
    }

    return WeeklyTreeState(
      stage: (json['stage'] as num?)?.toInt() ?? 1,
      stageTitle: json['stageTitle'] as String? ?? 'Semilla Brotando',
      stageSubtitle: json['stageSubtitle'] as String? ?? '',
      quests: quests,
      completedQuestsCount: (json['completedQuestsCount'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      claimedStage3Reward: json['claimedStage3Reward'] as bool? ?? false,
      claimedStage4Reward: json['claimedStage4Reward'] as bool? ?? false,
      daysLeftInWeek: (json['daysLeftInWeek'] as num?)?.toInt() ?? 7,
      weekLabel: json['weekLabel'] as String? ?? '',
    );
  }
}

/// Registro archivado de un árbol cosechado en una semana anterior.
class ArchivedTreeRecord {
  final String weekKey;
  final String weekLabel;
  final int stageReached;
  final String stageTitle;
  final double totalKg;
  final int questsCompleted;
  final DateTime achievedAt;

  const ArchivedTreeRecord({
    required this.weekKey,
    required this.weekLabel,
    required this.stageReached,
    required this.stageTitle,
    required this.totalKg,
    required this.questsCompleted,
    required this.achievedAt,
  });

  Map<String, dynamic> toJson() => {
        'weekKey': weekKey,
        'weekLabel': weekLabel,
        'stageReached': stageReached,
        'stageTitle': stageTitle,
        'totalKg': totalKg,
        'questsCompleted': questsCompleted,
        'achievedAt': achievedAt.toIso8601String(),
      };

  factory ArchivedTreeRecord.fromJson(Map<String, dynamic> json) =>
      ArchivedTreeRecord(
        weekKey: json['weekKey'] as String? ?? '',
        weekLabel: json['weekLabel'] as String? ?? '',
        stageReached: (json['stageReached'] as num?)?.toInt() ?? 1,
        stageTitle: json['stageTitle'] as String? ?? 'Semilla',
        totalKg: (json['totalKg'] as num?)?.toDouble() ?? 0.0,
        questsCompleted: (json['questsCompleted'] as num?)?.toInt() ?? 0,
        achievedAt: DateTime.tryParse(json['achievedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Servicio que evalúa el ciclo semanal (lunes 00:00 - domingo 23:59),
/// calcula las 6 misiones con datos reales y gestiona la Arboleda Histórica.
class HogarWeeklyQuestService {
  HogarWeeklyQuestService._();

  static const String _prefsGroveKey = 'hogar_archived_grove_trees';
  static const String _prefsStage3ClaimedPrefix = 'hogar_claimed_stage3_';
  static const String _prefsStage4ClaimedPrefix = 'hogar_claimed_stage4_';

  /// Retorna el inicio de la semana actual (lunes 00:00:00)
  static DateTime getStartOfWeek(DateTime now) {
    // DateTime.monday = 1, DateTime.sunday = 7
    final daysToSubtract = now.weekday - DateTime.monday;
    final monday = now.subtract(Duration(days: daysToSubtract));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Retorna el fin de la semana actual (domingo 23:59:59)
  static DateTime getEndOfWeek(DateTime now) {
    final start = getStartOfWeek(now);
    return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  /// Clave única de la semana (ej. "2026-W40")
  static String getWeekKey(DateTime date) {
    final start = getStartOfWeek(date);
    // Calcular número de semana aproximado
    final dayOfYear = int.parse("${date.difference(DateTime(date.year, 1, 1)).inDays}");
    final weekNum = ((dayOfYear - date.weekday + 10) / 7).floor();
    return '${start.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  /// Etiqueta amigable de la semana (ej. "Semana del 29 Sep al 5 Oct")
  static String getWeekFriendlyLabel(DateTime date) {
    final start = getStartOfWeek(date);
    final end = getEndOfWeek(date);
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'
    ];
    return '${start.day} ${months[start.month - 1]} - ${end.day} ${months[end.month - 1]}';
  }

  /// Evalúa el estado del árbol y las 6 misiones para la semana en curso.
  static Future<WeeklyTreeState> evaluateWeeklyState({
    required List<CollectionRequest> allRequests,
    required List<WalletTransaction> allTransactions,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final now = DateTime.now();
    final startOfWeek = getStartOfWeek(now);
    final endOfWeek = getEndOfWeek(now);
    final weekKey = getWeekKey(now);
    final daysLeft = endOfWeek.difference(now).inDays + 1;

    // 1. Filtrar solicitudes de recolección de esta semana
    final weeklyRequests = allRequests.where((r) {
      final dt = r.createdAt;
      if (dt == null) return false;
      return dt.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(endOfWeek.add(const Duration(seconds: 1)));
    }).toList();

    final completedWeeklyRequests =
        weeklyRequests.where((r) => r.status == 'COMPLETED').toList();

    // 2. Filtrar transacciones de billetera OUT (canje/compra en tienda) de esta semana
    final weeklyStorePurchases = allTransactions.where((t) {
      if (t.direction != 'OUT') return false;
      final dt = t.createdAt;
      if (dt == null) return false;
      return dt.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(endOfWeek.add(const Duration(seconds: 1)));
    }).toList();

    // --- EVALUACIÓN DE LAS 6 MISIONES ---

    // Misión 1: Entrega Real Verificada
    final completedCount = completedWeeklyRequests.length;
    final quest1 = WeeklyQuest(
      id: 'quest_1_completed_batch',
      title: 'Entrega Real Verificada',
      description: 'Completa al menos 1 entrega formal con pesaje del recolector.',
      icon: Icons.verified_rounded,
      color: const Color(0xFF00A878),
      isCompleted: completedCount >= 1,
      progressLabel: '$completedCount / 1 entrega',
      progressPercent: (completedCount >= 1) ? 1.0 : 0.0,
    );

    // Misión 2: Entrega Impecable (calificación de 5 estrellas o sin incidencias)
    final topRated = completedWeeklyRequests.where((r) => (r.rating ?? 5) >= 5).length;
    final quest2 = WeeklyQuest(
      id: 'quest_2_clean_delivery',
      title: 'Entrega Impecable',
      description: 'Lote separado y entregado con máxima valoración o sin observaciones.',
      icon: Icons.star_rounded,
      color: const Color(0xFF00B4D8),
      isCompleted: topRated >= 1,
      progressLabel: '$topRated / 1 entrega',
      progressPercent: (topRated >= 1) ? 1.0 : 0.0,
    );

    // Misión 3: Volumen de Impacto (≥ 5.0 kg pesados en la semana)
    double weeklyKg = 0.0;
    for (final r in completedWeeklyRequests) {
      final actual = r.actualWeights;
      if (actual != null && actual.isNotEmpty) {
        weeklyKg += actual.values.fold(0.0, (sum, val) => sum + val);
      } else {
        weeklyKg += r.itemsEstimated.values.fold(0.0, (sum, val) => sum + val);
      }
    }
    final quest3 = WeeklyQuest(
      id: 'quest_3_volume',
      title: 'Volumen de Impacto (≥ 5 kg)',
      description: 'Alcanza al menos 5.0 kg pesados acumulados durante la semana.',
      icon: Icons.scale_rounded,
      color: const Color(0xFF0077B6),
      isCompleted: weeklyKg >= 5.0,
      progressLabel: '${weeklyKg.toStringAsFixed(1)} / 5.0 kg',
      progressPercent: (weeklyKg / 5.0).clamp(0.0, 1.0),
    );

    // Misión 4: Separación Multimaterial (≥ 2 categorías distintas)
    final materialCategories = <String>{};
    for (final r in completedWeeklyRequests) {
      final actual = r.actualWeights;
      if (actual != null && actual.isNotEmpty) {
        materialCategories.addAll(actual.keys.map((k) => k.toUpperCase().trim()));
      } else {
        materialCategories.addAll(r.itemsEstimated.keys.map((k) => k.toUpperCase().trim()));
      }
    }
    final matCount = materialCategories.length;
    final quest4 = WeeklyQuest(
      id: 'quest_4_multi_material',
      title: 'Separación Multimaterial',
      description: 'Entrega al menos 2 materiales distintos valorizables (ej. Plástico y Cartón).',
      icon: Icons.category_rounded,
      color: const Color(0xFFF59E0B),
      isCompleted: matCount >= 2,
      progressLabel: '$matCount / 2 tipos',
      progressPercent: (matCount / 2.0).clamp(0.0, 1.0),
    );

    // Misión 5: Material de Alto Impacto (Vidrio o Metal/Aluminio)
    final hasHighImpactMaterial = materialCategories.any((m) =>
        m.contains('VIDRIO') ||
        m.contains('ALUMINIO') ||
        m.contains('METAL') ||
        m.contains('LATA'));
    final quest5 = WeeklyQuest(
      id: 'quest_5_high_impact_material',
      title: 'Material de Alto Impacto',
      description: 'Incluye al menos un lote con metales (aluminio) o vidrio reciclado.',
      icon: Icons.shield_rounded,
      color: const Color(0xFF8B5CF6),
      isCompleted: hasHighImpactMaterial,
      progressLabel: hasHighImpactMaterial ? '1 / 1 cumplido' : '0 / 1 cumplido',
      progressPercent: hasHighImpactMaterial ? 1.0 : 0.0,
    );

    // Misión 6: Consumo en Barrio (Canje con LIVO en tienda asociada)
    final storePurchasesCount = weeklyStorePurchases.length;
    final quest6 = WeeklyQuest(
      id: 'quest_6_store_redemption',
      title: 'Consumo en Comercio Aliado',
      description: 'Realiza al menos 1 canje o compra utilizando tokens LIVO en una tienda física.',
      icon: Icons.storefront_rounded,
      color: const Color(0xFFEAB308),
      isCompleted: storePurchasesCount >= 1,
      progressLabel: '$storePurchasesCount / 1 canje',
      progressPercent: (storePurchasesCount >= 1) ? 1.0 : 0.0,
    );

    final quests = [quest1, quest2, quest3, quest4, quest5, quest6];
    final completedCountTotal = quests.where((q) => q.isCompleted).length;

    // Determinar Etapa:
    // 0 a 1 misiones: Etapa 1 (Semilla)
    // 2 a 3 misiones: Etapa 2 (Brote con Tallo)
    // 4 a 5 misiones: Etapa 3 (Árbol Joven Floreciendo) -> +0.50 LIVO
    // 6 misiones: Etapa 4 (Gran Árbol Dorado Frondoso) -> +1.00 LIVO adicionales
    int stage;
    String stageTitle;
    String stageSubtitle;

    if (completedCountTotal < 2) {
      stage = 1;
      stageTitle = 'Semilla Brotando';
      stageSubtitle = 'Siembra tu esfuerzo completando tus primeras misiones.';
    } else if (completedCountTotal < 4) {
      stage = 2;
      stageTitle = 'Brote con Tallo';
      stageSubtitle = 'Tu hábito está echando raíces. Avanza hacia el árbol joven.';
    } else if (completedCountTotal < 6) {
      stage = 3;
      stageTitle = 'Árbol Joven Floreciendo';
      stageSubtitle = '¡Recompensa intermedia desbloqueada (+0.50 LIVO)! A 2 pasos del Árbol Dorado.';
    } else {
      stage = 4;
      stageTitle = 'Gran Árbol Dorado Frondoso';
      stageSubtitle = '¡Semana Perfecta! Corona dorada y máximo honor en tu Arboleda (+1.00 LIVO extra).';
    }

    final progressPercent = (completedCountTotal / 6.0).clamp(0.0, 1.0);
    final claimedStage3 = p.getBool('$_prefsStage3ClaimedPrefix$weekKey') ?? false;
    final claimedStage4 = p.getBool('$_prefsStage4ClaimedPrefix$weekKey') ?? false;

    // Auto-archivar en la arboleda si la semana avanzó
    await _checkAndArchivePreviousWeeks(p, currentWeekKey: weekKey, currentWeekTotalKg: weeklyKg, currentStage: stage);

    return WeeklyTreeState(
      stage: stage,
      stageTitle: stageTitle,
      stageSubtitle: stageSubtitle,
      quests: quests,
      completedQuestsCount: completedCountTotal,
      progressPercent: progressPercent,
      claimedStage3Reward: claimedStage3,
      claimedStage4Reward: claimedStage4,
      daysLeftInWeek: daysLeft.clamp(0, 7),
      weekLabel: getWeekFriendlyLabel(now),
    );
  }

  /// Recupera el historial de árboles cosechados en semanas pasadas
  static Future<List<ArchivedTreeRecord>> getGroveHistory([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getStringList(_prefsGroveKey) ?? [];
    return raw.map((str) {
      try {
        return ArchivedTreeRecord.fromJson(jsonDecode(str) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<ArchivedTreeRecord>().toList()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
  }

  /// Archiva la semana actual en la arboleda si alcanza un hito notable
  static Future<void> saveTreeToGrove({
    required String weekKey,
    required String weekLabel,
    required int stage,
    required String stageTitle,
    required double totalKg,
    required int questsCompleted,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final grove = await getGroveHistory(p);

    // Si ya existe la semana, actualizarla si alcanzó mayor etapa
    final existingIndex = grove.indexWhere((r) => r.weekKey == weekKey);
    final newRecord = ArchivedTreeRecord(
      weekKey: weekKey,
      weekLabel: weekLabel,
      stageReached: stage,
      stageTitle: stageTitle,
      totalKg: totalKg,
      questsCompleted: questsCompleted,
      achievedAt: DateTime.now(),
    );

    if (existingIndex >= 0) {
      if (grove[existingIndex].stageReached <= stage) {
        grove[existingIndex] = newRecord;
      }
    } else {
      grove.insert(0, newRecord);
    }

    final rawList = grove.map((r) => jsonEncode(r.toJson())).toList();
    await p.setStringList(_prefsGroveKey, rawList);
  }

  static Future<void> _checkAndArchivePreviousWeeks(
    SharedPreferences p, {
    required String currentWeekKey,
    required double currentWeekTotalKg,
    required int currentStage,
  }) async {
    final lastRecordedWeek = p.getString('hogar_last_active_week_key');
    if (lastRecordedWeek != null && lastRecordedWeek != currentWeekKey) {
      // Cambio de semana detectado: la semana anterior queda archivada
      p.setString('hogar_last_active_week_key', currentWeekKey);
    } else if (lastRecordedWeek == null) {
      p.setString('hogar_last_active_week_key', currentWeekKey);
    }
  }
}
