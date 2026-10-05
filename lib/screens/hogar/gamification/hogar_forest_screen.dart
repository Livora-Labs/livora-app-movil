import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/livora_api.dart';
import '../../../widgets/common.dart';
import '../../common/stores_catalog_screen.dart';
import '../hogar_kyc_screen.dart';
import 'hogar_weekly_quest_service.dart';
import 'parallax_ecosystem_canvas.dart';
import 'hogar_grove_history_modal.dart';

/// Pestaña central inmersiva 'Mi Bosque' en el Hogar:
/// Escenario superior con el Ecosistema Vivo Parallax (~55% de pantalla)
/// y hoja inferior deslizable con las 6 misiones semanales, recompensas y arboleda.
class HogarForestScreen extends StatefulWidget {
  const HogarForestScreen({super.key});

  @override
  State<HogarForestScreen> createState() => _HogarForestScreenState();
}

class _HogarForestScreenState extends State<HogarForestScreen> {
  WeeklyTreeState? _treeState;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final api = context.read<LivoraApi>();
    try {
      // 1. Intentar cargar el estado oficial y auditable del backend
      WeeklyTreeState? treeState;
      try {
        final backendJson = await api.getWeeklyForestState();
        treeState = WeeklyTreeState.fromBackendJson(backendJson);
      } catch (_) {
        // Fallback resiliente a cálculo local si no hay conexión temporal
        final results = await Future.wait([
          api.collectionRequests(),
          api.walletTransactions(page: 1, limit: 30),
        ]);
        final reqList = results[0] as List<CollectionRequest>? ?? const [];
        final txList = results[1] as List<WalletTransaction>? ?? const [];
        treeState = await HogarWeeklyQuestService.evaluateWeeklyState(
          allRequests: reqList,
          allTransactions: txList,
        );
      }

      if (!mounted) return;
      setState(() {
        _treeState = treeState;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo sincronizar el ecosistema';
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleClaimReward(String stageKey) async {
    HapticFeedback.lightImpact();
    final api = context.read<LivoraApi>();

    try {
      showAppSnack(context, 'Reclamando tu recompensa ambiental...');
      final res = await api.claimWeeklyForestReward(stageKey);
      if (!mounted) return;
      final msg = res['message'] as String? ?? '¡Recompensa acreditada!';
      showAppSnack(context, msg);
      await _loadState();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.contains('KYC') || e.message.contains('identidad') || e.statusCode == 400) {
        // Mostrar modal pedagógico para completar verificación de identidad
        await showDialog<void>(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 36),
            ),
            title: const Text('Validación de Identidad Requerida', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            content: const Text(
              'Tus recompensas en LIVOs están 100% aseguradas y reservadas a tu nombre. Conforme a ley (Ley N.° 29733 e Indecopi), valida tu DNI para habilitar tu billetera Stellar y recibir los tokens.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: LivoraColors.slate),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Más tarde'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HogarKycScreen()),
                  );
                },
                child: const Text('Validar Mi DNI'),
              ),
            ],
          ),
        );
      } else {
        showAppSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'No se pudo reclamar la recompensa en este momento', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: LivoraColors.paper,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _treeState == null) {
      return Scaffold(
        backgroundColor: LivoraColors.paper,
        appBar: AppBar(
          title: const Text('Mi Bosque'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error ?? 'Error cargando datos'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadState,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final state = _treeState!;
    final isGolden = state.stage == 4;

    return Scaffold(
      backgroundColor: LivoraColors.paper,
      body: RefreshIndicator(
        onRefresh: _loadState,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // 1. Escenario Inmersivo en SliverAppBar Parallax
            SliverAppBar(
              expandedHeight: 330,
              pinned: true,
              backgroundColor: const Color(0xFFBAE6FD),
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.forest_rounded, color: LivoraColors.deep, size: 20),
                  tooltip: 'Arboleda Histórica',
                  onPressed: () => HogarGroveHistoryModal.show(context),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 15,
                        color: isGolden ? const Color(0xFFB45309) : LivoraColors.forest,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${state.daysLeftInWeek}d restantes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isGolden ? const Color(0xFFB45309) : LivoraColors.forest,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    Positioned.fill(
                      child: ParallaxEcosystemCanvas(
                        stage: state.stage,
                        height: 330,
                      ),
                    ),
                    // Gradiente inferior para conectar con el cuerpo
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              LivoraColors.paper.withOpacity(0.9),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Tarjeta Resumen de Estado de Etapa
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isGolden
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                        : LivoraColors.border,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isGolden
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                          : LivoraColors.deep.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.stageTitle,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: isGolden
                                      ? const Color(0xFFB45309)
                                      : LivoraColors.deep,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.weekLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: LivoraColors.ink.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isGolden
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF00A878).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${state.completedQuestsCount}/6 MISIONES',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isGolden
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF00A878),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.stageSubtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: LivoraColors.ink.withValues(alpha: 0.8),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Barra segmentada en 4 etapas
                    _SegmentedStageProgress(
                      currentStage: state.stage,
                      completedCount: state.completedQuestsCount,
                    ),

                    // Banner de Reclamación de Recompensa (Etapa 3 o Etapa 4)
                    if (state.stage >= 3 && !state.claimedStage3Reward) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Color(0xFF059669), size: 24),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¡Premio Etapa 3 Desbloqueado!',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF065F46)),
                                  ),
                                  Text(
                                    '+0.50 LIVO disponible por hacer florecer tu árbol',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _handleClaimReward('STAGE_3'),
                              child: const Text('Reclamar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (state.stage >= 4 && !state.claimedStage4Reward) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB45309), size: 26),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¡Corona Dorada Perfecta (+1.00 LIVO)!',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF92400E)),
                                  ),
                                  Text(
                                    'Completaste las 6 misiones semanales',
                                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _handleClaimReward('STAGE_4'),
                              child: const Text('Reclamar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Encabezado de la lista de Misiones Semanales
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.military_tech_rounded, size: 20, color: LivoraColors.forest),
                    const SizedBox(width: 8),
                    const Text(
                      'Tus 6 Misiones Semanales',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Ciclo lunes a domingo',
                      style: TextStyle(
                        fontSize: 11,
                        color: LivoraColors.ink.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Lista desplegada de las 6 Misiones
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final quest = state.quests[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ExpandedQuestCard(
                        quest: quest,
                        index: index + 1,
                        onTapStoreCatalog: quest.id == 'quest_6_store_redemption' && !quest.isCompleted
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StoresCatalogScreen(),
                                  ),
                                );
                              }
                            : null,
                      ),
                    );
                  },
                  childCount: state.quests.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedQuestCard extends StatelessWidget {
  const _ExpandedQuestCard({
    required this.quest,
    required this.index,
    this.onTapStoreCatalog,
  });

  final WeeklyQuest quest;
  final int index;
  final VoidCallback? onTapStoreCatalog;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        // Relieve inferior estilo RPG / Duolingo táctil
        border: Border(
          top: BorderSide(
            color: quest.isCompleted
                ? quest.color.withValues(alpha: 0.35)
                : LivoraColors.border,
            width: 1.2,
          ),
          left: BorderSide(
            color: quest.isCompleted
                ? quest.color.withValues(alpha: 0.35)
                : LivoraColors.border,
            width: 1.2,
          ),
          right: BorderSide(
            color: quest.isCompleted
                ? quest.color.withValues(alpha: 0.35)
                : LivoraColors.border,
            width: 1.2,
          ),
          bottom: BorderSide(
            color: quest.isCompleted ? quest.color : const Color(0xFFCBD5E1),
            width: 3.5, // Reborde 3D presionante
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: quest.isCompleted
                ? quest.color.withValues(alpha: 0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medalla RPG con brillo esmaltado
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: quest.isCompleted
                      ? [quest.color.withValues(alpha: 0.25), quest.color.withValues(alpha: 0.12)]
                      : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: quest.isCompleted ? quest.color : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  quest.isCompleted ? Icons.check_circle_rounded : quest.icon,
                  color: quest.isCompleted ? quest.color : const Color(0xFF64748B),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Contenido
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
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: quest.isCompleted
                                ? LivoraColors.deep
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: quest.isCompleted
                              ? quest.color.withValues(alpha: 0.14)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          quest.progressLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: quest.isCompleted ? quest.color : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    quest.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Barra de progreso estilizada
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: quest.progressPercent,
                      minHeight: 6.5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        quest.isCompleted ? quest.color : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (onTapStoreCatalog != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onTapStoreCatalog,
                        icon: const Icon(Icons.storefront_rounded, size: 15, color: LivoraColors.forest),
                        label: const Text(
                          'Ir a tiendas aliadas',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isReached
                          ? (index == 3 ? const Color(0xFFF59E0B) : const Color(0xFF00A878))
                          : Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? (index == 3 ? const Color(0xFFB45309) : LivoraColors.deep)
                            : Colors.transparent,
                        width: 2.2,
                      ),
                    ),
                    child: Icon(
                      stage.icon,
                      size: 16,
                      color: isReached ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                  if (index < stages.length - 1)
                    Expanded(
                      child: Container(
                        height: 4.5,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stages.map((s) {
            final isReached = completedCount >= s.requiredQuests;
            return Text(
              s.name,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isReached ? FontWeight.w800 : FontWeight.w500,
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
