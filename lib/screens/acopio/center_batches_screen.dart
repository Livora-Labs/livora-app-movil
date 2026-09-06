import 'dart:async';
import 'dart:convert';

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
import '../../widgets/batch_detail_modal.dart';
import '../../widgets/common.dart';
import '../../widgets/live_indicator.dart';
import '../../widgets/livora_shimmer.dart';
import '../../widgets/livora_empty_state.dart';
import '../common/profile.dart';
import '../common/qr_scanner_view.dart';
import 'center_auctions_screen.dart';
import 'receive_batch_screen.dart';
import 'sale_screen.dart';

/// Lotes destinados al centro de acopio: recepción, pesaje y consolidación.
class CenterBatchesScreen extends StatefulWidget {
  const CenterBatchesScreen({super.key});

  @override
  State<CenterBatchesScreen> createState() => _CenterBatchesScreenState();
}

const _filters = <String?, String>{
  null: 'Todos',
  'IN_TRANSIT': 'En tránsito',
  'FLAGGED_FOR_REVIEW': 'Observados',
  'DISPUTED': 'En disputa',
  'PROCESSING': 'Procesando',
  'RECEIVED': 'Recibidos',
  'CONSOLIDATED': 'Consolidados',
};

class _CenterBatchesScreenState extends State<CenterBatchesScreen> {
  List<Batch>? _batches;
  String? _error;
  String? _filter;
  final Set<String> _selected = {};
  bool _consolidating = false;

  StreamSubscription<Map<String, dynamic>>? _liveSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    // El servidor nos suscribió a la sala `center:<id>`: cuando un lote
    // termina de procesarse en cadena, la lista se refresca sola.
    _liveSubscription = context
        .read<LivoraRealtime>()
        .on(RealtimeEvents.batchCompleted)
        .listen(_onBatchCompleted);
  }

  void _onBatchCompleted(Map<String, dynamic> data) {
    if (!mounted) return;
    _load();
    showAppSnack(context, 'Un lote terminó de procesarse');
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final batches =
          await context.read<LivoraApi>().batches(status: _filter);
      if (mounted) {
        setState(() {
          _batches = batches;
          _selected.removeWhere(
            (id) => !batches.any(
              (batch) => batch.id == id && batch.status == 'RECEIVED',
            ),
          );
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _settleFiat(Batch batch) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Confirmar Pago Fiat',
      message:
          '¿Confirmas que se ha realizado la entrega del pago en soles (PEN) al recolector por los materiales del Lote #${batch.shortId}?',
      confirmLabel: 'Sí, marcar como pagado',
      cancelLabel: 'Cancelar',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<LivoraApi>().settleBatchFiat(batch.id);
      if (mounted) {
        showAppSnack(context, 'Pago fiat registrado exitosamente');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Error al registrar el pago fiat', error: true);
    }
  }

  Future<void> _consolidate() async {
    final selectedBatches = _batches?.where((b) => _selected.contains(b.id)).toList() ?? [];
    final totalSelectedWeight = selectedBatches.fold<double>(
      0.0,
      (sum, b) => sum + (b.materialsActual?.values.fold<double>(0.0, (s, w) => s + w) ?? 0.0),
    );

    if (totalSelectedWeight <= 0) {
      showAppSnack(
        context,
        'No se puede consolidar: el peso total de los lotes seleccionados es 0 kg',
        error: true,
      );
      return;
    }

    final confirmed = await confirmDialog(
      context,
      title: 'Consolidar lotes',
      message:
          'Se consolidarán ${_selected.length} lote(s) (${fmtKg(totalSelectedWeight)}) en un único lote listo para la venta.',
      confirmLabel: 'Consolidar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _consolidating = true);
    try {
      final result = await context
          .read<LivoraApi>()
          .consolidateBatches(_selected.toList());
      if (!mounted) return;
      _selected.clear();
      final totalWeight =
          double.tryParse('${result['totalWeight'] ?? ''}') ?? totalSelectedWeight;
      final goToSale = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: LivoraColors.green,
            size: 40,
          ),
          title: const Text('Lote consolidado'),
          content: Text(
            'Peso total: ${fmtKg(totalWeight)}\nEstado: pendiente de venta.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Registrar venta'),
            ),
          ],
        ),
      );
      if (goToSale == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SaleScreen(initialWeightKg: totalWeight),
          ),
        );
      }
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _consolidating = false);
    }
  }

  Future<void> _showResolveDiscrepancyDialog(Batch batch) async {
    final noteController = TextEditingController(
      text: 'Aprobado tras calibración física y re-pesaje en báscula',
    );
    final formKey = GlobalKey<FormState>();
    bool resolving = false;

    final resolved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.shield_outlined,
            color: LivoraColors.forest,
            size: 36,
          ),
          title: Text('Resolver Lote #${batch.shortId}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (batch.discrepancyNote != null && batch.discrepancyNote!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: LivoraColors.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: LivoraColors.coral.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      batch.discrepancyNote!,
                      style: const TextStyle(fontSize: 11, color: LivoraColors.deep),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const Text(
                  'Ingresa la justificación técnica para autorizar este lote y enviarlo a liquidación en blockchain:',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nota de justificación técnica',
                    hintText: 'Ej. Tolerancia física aceptada...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Ingresa una justificación técnica (mínimo 5 caracteres)'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: resolving ? null : () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
              onPressed: resolving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => resolving = true);
                      try {
                        await context
                            .read<LivoraApi>()
                            .overrideBatchDiscrepancy(
                              batch.id,
                              noteController.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(dialogCtx, true);
                      } on ApiException catch (e) {
                        if (ctx.mounted) {
                          showAppSnack(ctx, e.message, error: true);
                          setDialogState(() => resolving = false);
                        }
                      }
                    },
              child: resolving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Autorizar y Procesar'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (resolved == true && mounted) {
      showAppSnack(
        context,
        'Discrepancia autorizada. El lote ha sido enviado a procesamiento blockchain.',
      );
      _load();
    }
  }

  Future<void> _showPin() async {
    final api = context.read<LivoraApi>();
    try {
      var pin = await api.receptionPin();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (builderContext, setDialogState) => AlertDialog(
            title: const Text('PIN de recepción'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pin,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
                    color: LivoraColors.forest,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Compártelo con los recolectores que entregan lotes en tu centro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await HapticFeedback.lightImpact();
                  await Clipboard.setData(ClipboardData(text: pin));
                  if (builderContext.mounted) {
                    showAppSnack(
                      builderContext,
                      'PIN $pin copiado al portapapeles',
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copiar PIN'),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    final newPin = await api.refreshReceptionPin();
                    setDialogState(() => pin = newPin);
                  } on ApiException catch (error) {
                    if (builderContext.mounted) {
                      showAppSnack(
                        builderContext,
                        error.message,
                        error: true,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Regenerar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _scanIncomingBatch() async {
    // Vista previa explicativa en español (Rationale Modal) antes de pedir permiso de cámara
    final shouldOpenScanner = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.qr_code_scanner_rounded,
          color: LivoraColors.forest,
          size: 40,
        ),
        title: const Text('Acceso a la Cámara'),
        content: const Text(
          'Livora requiere acceso a la cámara para escanear el código QR del lote presentado por el recolector o transportista.\n\nTus fotos y archivos privados no se almacenan ni comparten en la nube.',
          style: TextStyle(fontSize: 13),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LivoraColors.forest,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir Escáner'),
          ),
        ],
      ),
    );

    if (shouldOpenScanner != true || !mounted) return;

    HapticFeedback.lightImpact();
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerView()),
    );
    if (scanned == null || scanned.trim().isEmpty || !mounted) return;

    final session = context.read<SessionController>();
    final currentCenterId = session.user?.id;
    final api = context.read<LivoraApi>();

    String batchId = scanned.trim();

    try {
      final decoded = jsonDecode(scanned);
      if (decoded is Map) {
        batchId = decoded['batchId'] as String? ?? batchId;
      }
    } catch (_) {
      // Scanned raw string
    }

    try {
      final batch = await api.batchDetail(batchId);

      // Validar si destinationCenterId coincide con el centro autenticado
      if (currentCenterId != null &&
          batch.destinationCenterId != null &&
          batch.destinationCenterId!.isNotEmpty &&
          batch.destinationCenterId != currentCenterId) {
        if (mounted) {
          showAppSnack(
            context,
            'Este lote está destinado a otro Centro de Acopio (${batch.destinationCenterName ?? batch.destinationCenterId})',
            error: true,
          );
        }
        return;
      }

      if (!mounted) return;
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiveBatchScreen(batch: batch),
        ),
      );
      if (result == true) {
        _load();
      } else if (result == 'FLAGGED_FOR_REVIEW') {
        setState(() => _filter = 'FLAGGED_FOR_REVIEW');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo verificar el lote escaneado',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = _batches;
    final selectedBatches = batches?.where((b) => _selected.contains(b.id)).toList() ?? [];
    final totalWeight = selectedBatches.fold<double>(
      0.0,
      (sum, b) => sum + b.totalActualKg,
    );

    return Scaffold(
      appBar: livoraAppBar(
        context,
        'Lotes',
        actions: [
          const LiveIndicator(),
          IconButton(
            tooltip: 'Mercado de Órdenes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CenterAuctionsScreen()),
              );
            },
            icon: const Icon(Icons.storefront_rounded),
          ),
          IconButton(
            tooltip: 'Escanear QR de Lote',
            onPressed: _scanIncomingBatch,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: 'PIN de recepción',
            onPressed: _showPin,
            icon: const Icon(Icons.pin_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanIncomingBatch,
        backgroundColor: LivoraColors.forest,
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text(
          'Escanear Lote',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: BusyButton(
                  label: totalWeight > 0
                      ? 'Consolidar ${_selected.length} lote(s) (${totalWeight.toStringAsFixed(1)} kg)'
                      : 'Consolidar ${_selected.length} lote(s)',
                  icon: Icons.merge_type,
                  busy: _consolidating,
                  onPressed: totalWeight > 0 ? _consolidate : null,
                ),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in _filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _filter == entry.key,
                        selectedColor:
                            LivoraColors.mint.withValues(alpha: 0.3),
                        onSelected: (_) {
                          setState(() {
                            _filter = entry.key;
                            _batches = null;
                          });
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                title: 'No se pudieron cargar los lotes',
                message: _error,
              )
            else if (batches == null)
              const LivoraShimmerList(
                itemCount: 4,
                padding: EdgeInsets.zero,
              )
            else if (batches.isEmpty)
              LivoraEmptyState(
                icon: Icons.warehouse_rounded,
                title: 'No hay lotes',
                message:
                    'Cuando un recolector envíe un lote a tu centro aparecerá aquí.',
                actionLabel: 'Escanear Lote',
                onAction: _scanIncomingBatch,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              )
            else
              for (final batch in batches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BatchCard(
                    batch: batch,
                    selected: _selected.contains(batch.id),
                    onToggleSelect: batch.status == 'RECEIVED'
                        ? () => setState(() {
                              if (!_selected.remove(batch.id)) {
                                _selected.add(batch.id);
                              }
                            })
                        : null,
                    onReceive: batch.status == 'IN_TRANSIT'
                        ? () async {
                            final received = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReceiveBatchScreen(batch: batch),
                              ),
                            );
                            if (received == true) _load();
                          }
                        : null,
                    onResolveDiscrepancy: batch.status == 'FLAGGED_FOR_REVIEW'
                        ? () => _showResolveDiscrepancyDialog(batch)
                        : null,
                    onSettleFiat: batch.status == 'RECEIVED' && !batch.fiatSettled
                        ? () => _settleFiat(batch)
                        : null,
                    onViewDetail: () async {
                      final updated = await BatchDetailModal.show(context, batch: batch);
                      if (updated == true && mounted) _load();
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.selected,
    this.onToggleSelect,
    this.onReceive,
    this.onResolveDiscrepancy,
    this.onSettleFiat,
    this.onViewDetail,
  });

  final Batch batch;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onReceive;
  final VoidCallback? onResolveDiscrepancy;
  final VoidCallback? onSettleFiat;
  final VoidCallback? onViewDetail;

  @override
  Widget build(BuildContext context) {
    final materials = batch.materialsActual;
    final collectorDisplay = batch.collectorName != null && batch.collectorName!.trim().isNotEmpty
        ? batch.collectorName!
        : (batch.collectorEmail != null && batch.collectorEmail!.contains('@'))
            ? batch.collectorEmail!.split('@').first
            : (batch.collectorEmail ?? 'Recolector');

    return Card(
      child: InkWell(
        onTap: onToggleSelect ?? onViewDetail,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onToggleSelect != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        selected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: selected
                            ? LivoraColors.forest
                            : LivoraColors.ink.withValues(alpha: 0.5),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'Lote #${batch.shortId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                  if (onViewDetail != null)
                    IconButton(
                      icon: const Icon(Icons.receipt_long_outlined, size: 20, color: LivoraColors.forest),
                      tooltip: 'Ver Recibo y Trazabilidad',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onViewDetail,
                    ),
                  const SizedBox(width: 8),
                  StatusChip(
                    label: batchStatusLabel(batch.status),
                    color: batchStatusColor(batch.status),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Recolector: $collectorDisplay · ${fmtDate(batch.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: LivoraColors.ink.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                materials != null && materials.isNotEmpty
                    ? 'Pesaje real: ${materialsSummary(materials)}'
                    : 'Estimado: ${materialsSummary(batch.estimatedMaterials)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: LivoraColors.deep,
                ),
              ),
              if (batch.status == 'RECEIVED') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      batch.fiatSettled ? Icons.check_circle : Icons.schedule,
                      size: 14,
                      color: batch.fiatSettled ? LivoraColors.green : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      batch.fiatSettled ? 'Pago Fiat: Liquidado' : 'Pago Fiat: Pendiente',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: batch.fiatSettled ? LivoraColors.green : Colors.amber.shade800,
                      ),
                    ),
                    const Spacer(),
                    if (!batch.fiatSettled && onSettleFiat != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          side: const BorderSide(color: LivoraColors.forest),
                        ),
                        onPressed: onSettleFiat,
                        icon: const Icon(Icons.payments_outlined, size: 14, color: LivoraColors.forest),
                        label: const Text(
                          'Pagar Fiat',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LivoraColors.forest),
                        ),
                      ),
                  ],
                ),
              ],
              if (batch.status == 'DISPUTED') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.gavel_rounded, size: 18, color: Colors.purple.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          batch.disputeReason != null && batch.disputeReason!.isNotEmpty
                              ? 'En arbitraje: ${batch.disputeReason}'
                              : 'Lote en arbitraje administrativo por discrepancia',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.purple.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (batch.status == 'FLAGGED_FOR_REVIEW') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LivoraColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: LivoraColors.coral.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: LivoraColors.coral,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lote observado por discrepancia de peso (>15%)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: LivoraColors.coral,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (batch.discrepancyNote != null &&
                          batch.discrepancyNote!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          batch.discrepancyNote!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: LivoraColors.deep,
                          ),
                        ),
                      ],
                      if (onResolveDiscrepancy != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LivoraColors.coral,
                              side: const BorderSide(color: LivoraColors.coral),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                            ),
                            onPressed: onResolveDiscrepancy,
                            icon: const Icon(Icons.shield_outlined, size: 16),
                            label: const Text(
                              'Resolver Discrepancia',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (onReceive != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: onReceive,
                    icon: const Icon(Icons.scale_outlined),
                    label: const Text('Recibir y pesar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

