import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/batch_detail_modal.dart';
import '../../widgets/batch_dispatch_modal.dart';
import '../../widgets/common.dart';
import '../../widgets/verification_otp_modal.dart';
import '../../widgets/livora_shimmer.dart';
import '../../widgets/livora_empty_state.dart';
import '../common/profile.dart';

/// Pantalla de gestión de carga segmentada por Centro de Acopio ("Mi Lote en Ruta"):
/// Permite al recolector visualizar y gestionar múltiples sub-lotes abiertos simultáneos
/// en su vehículo, desglosados por centro comprador, con despacho independiente a planta.
class MyBatchScreen extends StatefulWidget {
  const MyBatchScreen({super.key});

  @override
  State<MyBatchScreen> createState() => _MyBatchScreenState();
}

class _MyBatchScreenState extends State<MyBatchScreen> {
  List<Batch>? _openBatches;
  List<Batch>? _history;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<LivoraApi>();
    try {
      final results = await Future.wait([api.openBatches(), api.batches()]);
      if (!mounted) return;
      setState(() {
        _openBatches = results[0].where((b) => b.status == 'OPEN').toList();
        _history = results[1].where((b) => b.status != 'OPEN').toList();
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron sincronizar los lotes');
      }
    }
  }

  Future<void> _deliverToAcopio(Batch batch) async {
    HapticFeedback.lightImpact();
    final dispatched = await BatchDispatchModal.show(context, batch: batch);
    if (dispatched == true && mounted) {
      _load();
    }
  }

  Future<void> _verifyPin(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    final verified = await VerificationOtpModal.show(context, request: request);
    if (verified == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final openBatches = _openBatches;
    final history = _history;

    // Calcular estadísticas globales acumuladas en todo el vehículo
    final grandTotalEstimatedKg = openBatches?.fold<double>(
          0.0,
          (sum, b) => sum + b.totalEstimatedKg,
        ) ??
        0.0;
    final totalCompletedStops = openBatches?.fold<int>(
          0,
          (sum, b) =>
              sum + b.requests.where((r) => r.status == 'COMPLETED').length,
        ) ??
        0;
    final totalInRouteStops = openBatches?.fold<int>(
          0,
          (sum, b) => sum +
              b.requests
                  .where((r) => r.status == 'ACCEPTED' || r.status == 'IN_ROUTE')
                  .length,
        ) ??
        0;

    return Scaffold(
      appBar: livoraAppBar(context, 'Mi Lote en Ruta'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Indicador reactivo de cola offline pendiente de sincronizar
            ValueListenableBuilder<int>(
              valueListenable: OfflineQueueManager.pendingListenable,
              builder: (context, pending, _) {
                if (pending <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: LivoraColors.forest.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: LivoraColors.forest.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: LivoraColors.forest,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sincronizando $pending recolección(es) guardada(s) localmente...',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reintentar sincronización',
                          icon: const Icon(
                            Icons.sync,
                            size: 20,
                            color: LivoraColors.forest,
                          ),
                          onPressed: () => OfflineQueueManager.processQueue(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // CABECERA GLOBAL STICKY: Carga Total en Camión
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: LivoraColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              LivoraColors.forest.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            color: LivoraColors.forest,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Carga Total en Camioneta',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: LivoraColors.deep,
                                ),
                              ),
                              Text(
                                '${openBatches?.length ?? 0} sub-lote(s) activo(s) en ruta',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: LivoraColors.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          fmtKg(grandTotalEstimatedKg),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: LivoraColors.paper,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: LivoraColors.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$totalCompletedStops completadas',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: LivoraColors.deep,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 16,
                            width: 1,
                            color: LivoraColors.border,
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.navigation_outlined,
                                size: 16,
                                color: LivoraColors.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$totalInRouteStops en ruta',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: LivoraColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                title: 'No se pudieron cargar tus lotes',
                message: _error,
              )
            else if (openBatches == null)
              const LivoraShimmerList(
                itemCount: 3,
                padding: EdgeInsets.zero,
              )
            else if (openBatches.isEmpty)
              const LivoraEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No hay lotes abiertos en ruta',
                message:
                    'Acepta solicitudes en el radar para iniciar la recolección y acumulación por Centro de Acopio.',
                padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
              )
            else ...[
              const SectionTitle(text: 'Sub-Lotes Abiertos por Acopio'),
              const SizedBox(height: 6),

              // LISTA VERTICAL DE TARJETAS INDEPENDIENTES POR SUB-LOTE / ACOPIO
              for (final batch in openBatches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SegmentedBatchCard(
                    batch: batch,
                    onVerifyPin: _verifyPin,
                    onDeliver: () => _deliverToAcopio(batch),
                  ),
                ),
            ],

            const SizedBox(height: 16),
            const SectionTitle(text: 'Historial de Lotes Entregados'),
            if (history == null || history.isEmpty)
              const LivoraEmptyState(
                icon: Icons.history_outlined,
                title: 'Sin lotes anteriores',
                message:
                    'Cuando entregues y se liquiden tus lotes en las plantas de acopio, aparecerán aquí.',
                padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
              )
            else
              for (final item in history)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: LivoraColors.border),
                    ),
                    child: ListTile(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final updated = await BatchDetailModal.show(context, batch: item);
                        if (updated == true && mounted) _load();
                      },
                      title: Row(
                        children: [
                          Text(
                            'Lote #${item.shortId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.deep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: batchStatusLabel(item.status),
                            color: batchStatusColor(item.status),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destino: ${sanitizedCenterName(item.destinationCenterName, item.destinationCenterEmail, defaultLabel: 'Acopio')} · ${fmtDate(item.createdAt)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (item.status == 'FLAGGED_FOR_REVIEW') ...[
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 14, color: LivoraColors.coral),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Pesaje observado (>15% discrepancia). Toca para impugnar.',
                                    style: TextStyle(fontSize: 11, color: LivoraColors.coral, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (item.status == 'DISPUTED') ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.gavel_rounded, size: 14, color: Colors.purple.shade700),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'En proceso de arbitraje administrativo.',
                                    style: TextStyle(fontSize: 11, color: Colors.purple.shade800, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta autónoma para un sub-lote específico agrupado por Centro de Acopio comprador
class _SegmentedBatchCard extends StatelessWidget {
  const _SegmentedBatchCard({
    required this.batch,
    required this.onVerifyPin,
    required this.onDeliver,
  });

  final Batch batch;
  final ValueChanged<CollectionRequest> onVerifyPin;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    final centerName = sanitizedCenterName(
      batch.destinationCenterName,
      batch.destinationCenterEmail,
      defaultLabel: 'Centro de Acopio Asignado',
    );
    final centerAddress = batch.destinationCenterAddress?.isNotEmpty == true
        ? batch.destinationCenterAddress!
        : 'Planta de Acopio Comprador';

    final totalBatchKg = batch.totalEstimatedKg;
    final accumulatedMaterials = batch.estimatedMaterials;
    final completedCount =
        batch.requests.where((r) => r.status == 'COMPLETED').length;
    final inRouteCount = batch.requests
        .where((r) => r.status == 'ACCEPTED' || r.status == 'IN_ROUTE')
        .length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la Tarjeta: Nombre de Acopio y Badge de Lote
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warehouse_rounded,
                            size: 18,
                            color: LivoraColors.forest,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              centerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: LivoraColors.deep,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        centerAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: LivoraColors.ink.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: 'Sub-lote #${batch.shortId}',
                  color: LivoraColors.mint,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Resumen de carga y paradas para este acopio
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LivoraColors.paper,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Carga de este lote',
                          style: TextStyle(fontSize: 11, color: LivoraColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmtKg(totalBatchKg),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: LivoraColors.deep,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 32, width: 1, color: LivoraColors.border),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paradas asignadas',
                          style: TextStyle(fontSize: 11, color: LivoraColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$completedCount completada(s) · $inRouteCount en ruta',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Desglose de materiales acumulados
            const Text(
              'Materiales acumulados para este acopio:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: LivoraColors.deep,
              ),
            ),
            const SizedBox(height: 6),
            if (accumulatedMaterials.isEmpty)
              Text(
                'Aún no hay kilogramos pesados para este acopio.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: LivoraColors.ink.withValues(alpha: 0.6),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: accumulatedMaterials.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: LivoraColors.forest.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: LivoraColors.forest.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.recycling_rounded,
                          size: 13,
                          color: LivoraColors.forest,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${materialLabel(e.key)}: ${fmtKg(e.value)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.deep,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),

            // Recolecciones asignadas a este sub-lote
            if (batch.requests.isNotEmpty) ...[
              const Text(
                'Órdenes en este sub-lote:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: LivoraColors.deep,
                ),
              ),
              const SizedBox(height: 6),
              for (final req in batch.requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LivoraColors.paper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: req.status == 'COMPLETED'
                            ? LivoraColors.green.withValues(alpha: 0.3)
                            : LivoraColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.householdName?.isNotEmpty == true
                                    ? req.householdName!
                                    : 'Hogar',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: LivoraColors.deep,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                materialsSummary(req.itemsEstimated),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: LivoraColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (req.status == 'ACCEPTED' || req.status == 'IN_ROUTE')
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: LivoraColors.forest,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () => onVerifyPin(req),
                            icon: const Icon(Icons.pin_outlined, size: 14),
                            label: const Text(
                              'Validar PIN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (req.status == 'COMPLETED')
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: LivoraColors.green,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Completada',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: LivoraColors.green,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 14),

            // BOTÓN PRINCIPAL INDEPENDIENTE: Entregar Lote a [Nombre de Acopio]
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: LivoraColors.deep,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onDeliver,
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: Text(
                'Entregar Lote a $centerName',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
