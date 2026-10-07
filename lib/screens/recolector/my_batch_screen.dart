import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/batch_detail_modal.dart';
import '../../widgets/batch_dispatch_modal.dart';
import '../../widgets/common.dart';
import '../../widgets/verification_otp_modal.dart';
import '../../widgets/livora_shimmer.dart';
import '../../widgets/livora_empty_state.dart';
import '../common/profile.dart';
import '../shell/home_shell.dart';
import 'widgets/collector_batch_card.dart';

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
  int? _lastBatchesVersion;
  bool _loadInProgress = false;
  final List<StreamSubscription> _realtimeSubs = [];

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
    _load();
  }

  void _subscribeRealtime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final realtime = context.read<LivoraRealtime>();
      void onEvent(_) {
        if (mounted && !_loadInProgress) _load();
      }

      _realtimeSubs.add(realtime.on(RealtimeEvents.collectionUpdated).listen(onEvent));
      _realtimeSubs.add(realtime.on(RealtimeEvents.batchCompleted).listen(onEvent));
      _realtimeSubs.add(realtime.on(RealtimeEvents.batchDispatched).listen(onEvent));
      _realtimeSubs.add(realtime.on(RealtimeEvents.batchUpdated).listen(onEvent));
      _realtimeSubs.add(realtime.on(RealtimeEvents.batchFiatSettled).listen(onEvent));
    });
  }

  @override
  void dispose() {
    for (final sub in _realtimeSubs) {
      sub.cancel();
    }
    _realtimeSubs.clear();
    super.dispose();
  }

  // NOTE: didChangeDependencies is NOT reliable for IndexedStack-mounted widgets
  // because Provider rebuilds come through build(), not lifecycle hooks.
  // We track the version in build() with addPostFrameCallback to safely trigger
  // a reload without calling setState during the build phase.


  Future<void> _load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
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
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _deliverToAcopio(Batch batch) async {
    HapticFeedback.lightImpact();
    final dispatched = await BatchDispatchModal.show(context, batch: batch);
    if (dispatched == true && mounted) {
      context.read<SessionController>().notifyBatchesChanged();
      _load();
    }
  }

  Future<void> _verifyPin(CollectionRequest request) async {
    HapticFeedback.lightImpact();
    final verified = await VerificationOtpModal.show(context, request: request);
    if (verified == true && mounted) {
      context.read<SessionController>().notifyBatchesChanged();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observar SessionController en build() para que Provider pueda notificarnos
    // incluso cuando estamos en un IndexedStack no visible. Cuando batchesVersion
    // cambia (ej. validación de PIN en otra pestaña), programamos _load() en el
    // siguiente frame para no llamar setState() durante la fase de build.
    final session = context.watch<SessionController>();
    final currentVersion = session.batchesVersion;
    if (_lastBatchesVersion != null &&
        _lastBatchesVersion != currentVersion &&
        !_loadInProgress) {
      _lastBatchesVersion = currentVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    } else {
      _lastBatchesVersion ??= currentVersion;
    }

    const vehicleCapacity = 350.0;

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
                  .where((r) =>
                      r.status == 'ACCEPTED' ||
                      r.status == 'EN_ROUTE' ||
                      r.status == 'ARRIVED')
                  .length,
        ) ??
        0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Lotes'),
          actions: const [
            ProfileButton(),
            SizedBox(width: 6),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.local_shipping_outlined),
                text: 'En Ruta',
              ),
              Tab(
                icon: Icon(Icons.history_rounded),
                text: 'Historial',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // PESTAÑA 1: En Ruta (Lotes activos)
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
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

                  // CABECERA GLOBAL: Carga Total en Tránsito (transporte neutral)
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
                                  Icons.inventory_2_rounded,
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
                                      'Carga Total en Tránsito',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: LivoraColors.deep,
                                      ),
                                    ),
                                    Text(
                                      '${openBatches?.length ?? 0} sub-lote(s) activo(s)',
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
                    LivoraEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No hay lotes abiertos en ruta',
                      message:
                          'Acepta solicitudes en el radar para iniciar la recolección y acumulación por Centro de Acopio.',
                      actionLabel: 'Explorar Radar de Solicitudes',
                      onAction: () => HomeShell.switchTab(context, 0),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    )
                  else ...[
                    const SectionTitle(text: 'Sub-Lotes Abiertos por Acopio'),
                    const SizedBox(height: 6),
                    for (final batch in openBatches)
                      CollectorBatchCard(
                        batch: batch,
                        vehicleCapacityKg: vehicleCapacity,
                        onVerifyPin: _verifyPin,
                        onDeliver: () => _deliverToAcopio(batch),
                      ),
                  ],
                ],
              ),
            ),

            // PESTAÑA 2: Historial de Entregas
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                children: [
                  if (_error != null)
                    EmptyState(
                      icon: Icons.cloud_off,
                      title: 'No se pudo cargar el historial',
                      message: _error,
                    )
                  else if (history == null)
                    const LivoraShimmerList(
                      itemCount: 3,
                      padding: EdgeInsets.zero,
                    )
                  else if (history.isEmpty)
                    const LivoraEmptyState(
                      icon: Icons.history_outlined,
                      title: 'Sin lotes anteriores',
                      message:
                          'Cuando entregues y se liquiden tus lotes en las plantas de acopio, aparecerán aquí.',
                      padding: EdgeInsets.fromLTRB(24, 48, 24, 40),
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
                                if (item.status == 'RECEIVED' || item.status == 'CONSOLIDATED' || item.status == 'COMPLETED') ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        item.fiatSettled ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                        size: 13,
                                        color: item.fiatSettled ? LivoraColors.green : Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.fiatSettled
                                            ? 'Pago en efectivo: Entregado en mano'
                                            : 'Pago en efectivo: Pendiente de cobro en centro',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: item.fiatSettled ? LivoraColors.green : Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}
