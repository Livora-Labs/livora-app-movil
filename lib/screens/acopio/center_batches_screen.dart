import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';
import '../../widgets/common.dart';
import '../../widgets/live_indicator.dart';
import '../common/profile.dart';
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

  Future<void> _consolidate() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Consolidar lotes',
      message:
          'Se consolidarán ${_selected.length} lote(s) recibidos en un único lote listo para la venta.',
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
          double.tryParse('${result['totalWeight'] ?? ''}') ?? 0;
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
                icon: const Icon(Icons.refresh),
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

  @override
  Widget build(BuildContext context) {
    final batches = _batches;

    return Scaffold(
      appBar: livoraAppBar(
        context,
        'Lotes',
        actions: [
          const LiveIndicator(),
          IconButton(
            tooltip: 'PIN de recepción',
            onPressed: _showPin,
            icon: const Icon(Icons.pin_outlined),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: BusyButton(
                  label: 'Consolidar ${_selected.length} lote(s)',
                  icon: Icons.merge_type,
                  busy: _consolidating,
                  onPressed: _consolidate,
                ),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (batches.isEmpty)
              const EmptyState(
                icon: Icons.warehouse_outlined,
                title: 'No hay lotes',
                message:
                    'Cuando un recolector envíe un lote a tu centro aparecerá aquí.',
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
  });

  final Batch batch;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final materials = batch.materialsActual;
    return Card(
      child: InkWell(
        onTap: onToggleSelect,
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
                  StatusChip(
                    label: batchStatusLabel(batch.status),
                    color: batchStatusColor(batch.status),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Recolector: ${batch.collectorEmail ?? '—'} · ${fmtDate(batch.createdAt)}',
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
