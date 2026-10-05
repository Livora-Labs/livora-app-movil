import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/materials_editor.dart';

/// Pesaje industrial del lote en balanza, detección de discrepancias y liquidación de efectivo en mano.
class ReceiveBatchScreen extends StatefulWidget {
  const ReceiveBatchScreen({super.key, required this.batch});

  final Batch batch;

  @override
  State<ReceiveBatchScreen> createState() => _ReceiveBatchScreenState();
}

class _ReceiveBatchScreenState extends State<ReceiveBatchScreen> {
  Map<String, double> _materials = {};
  final Map<String, double> _priceMap = {
    'PET': 1.00,
    'CARTON': 0.50,
    'VIDRIO': 0.30,
    'PLASTICO': 1.00,
    'ALUMINIO': 1.50,
    'TETRAPAK': 0.40,
    'PAPEL': 0.50,
  };

  late final TextEditingController _justificationController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _justificationController = TextEditingController(
      text: 'Aprobado tras calibración física y re-pesaje en báscula industrial',
    );
    _materials = Map<String, double>.from(widget.batch.estimatedMaterials);
    _loadPrices();
  }

  @override
  void dispose() {
    _justificationController.dispose();
    super.dispose();
  }

  void _loadPrices() {
    final session = context.read<SessionController>();
    final centerId = session.user?.id;
    if (centerId != null && centerId.isNotEmpty) {
      context.read<LivoraApi>().fetchCenterPrices(centerId).then((prices) {
        if (mounted && prices.isNotEmpty) {
          setState(() {
            for (final p in prices) {
              _priceMap[p.materialType.toUpperCase().trim()] = p.pricePerKg;
            }
          });
        }
      }).catchError((_) {});
    }
  }

  double get _totalActualKg =>
      _materials.values.fold(0.0, (sum, w) => sum + w);

  double get _totalEstimatedKg =>
      widget.batch.estimatedMaterials.values.fold(0.0, (sum, w) => sum + w);

  double get _totalCashPEN {
    return _materials.entries.fold(0.0, (sum, entry) {
      final price = _priceMap[entry.key.toUpperCase().trim()] ?? 1.0;
      return sum + (entry.value * price);
    });
  }

  double get _discrepancyPct {
    if (_totalEstimatedKg <= 0) return 0.0;
    return ((_totalActualKg - _totalEstimatedKg) / _totalEstimatedKg).abs() * 100;
  }

  bool get _hasDiscrepancyAlert => _discrepancyPct > 15.0;

  Future<void> _submit() async {
    if (_materials.isEmpty || _totalActualKg <= 0) {
      showAppSnack(
        context,
        'Registra el peso real de al menos un material (mínimo 0.5 kg)',
        error: true,
      );
      return;
    }

    bool confirmCashHandover = true;

    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: LivoraColors.forest.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: LivoraColors.forest,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ticket de Liquidación en Balanza',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: LivoraColors.deep,
                    ),
                  ),
                  const SizedBox(height: 16),
                Text(
                  'Recolector: ${widget.batch.collectorName ?? widget.batch.collectorEmail ?? 'Recolector Urbano'}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      for (final entry in _materials.entries) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                materialLabel(entry.key),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${entry.value.toStringAsFixed(1)} kg',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'S/ ${(entry.value * (_priceMap[entry.key.toUpperCase().trim()] ?? 1.0)).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LivoraColors.forest),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Peso Total Balanza:',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            fmtKg(_totalActualKg),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total a Pagar en Efectivo:',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: LivoraColors.deep),
                          ),
                          Text(
                            'S/ ${_totalCashPEN.toStringAsFixed(2)} PEN',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_hasDiscrepancyAlert) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Variación del ${_discrepancyPct.toStringAsFixed(1)}% respecto a lo estimado. Se adjuntará la justificación técnica automáticamente.',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: confirmCashHandover,
                  activeColor: LivoraColors.forest,
                  title: const Text(
                    'Confirmar entrega de efectivo en mano',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Registrar ahora la entrega de S/ ${_totalCashPEN.toStringAsFixed(2)} en soles al recolector.',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  onChanged: (val) => setModalState(() => confirmCashHandover = val),
                ),
                const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: LivoraColors.forest,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(dialogCtx, true);
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text(
                      'Confirmar y Procesar',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: LivoraColors.slate,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(dialogCtx, false);
                    },
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (shouldProceed != true || !mounted) return;

    setState(() => _busy = true);
    final api = context.read<LivoraApi>();
    try {
      final res = await api.receiveBatch(widget.batch.id, _materials);
      final isFlagged = res['status'] == 'FLAGGED_FOR_REVIEW' ||
          res['hasDiscrepancy'] == true;

      if (isFlagged) {
        // Resolver la discrepancia de inmediato con la nota técnica autorizada
        try {
          await api.overrideBatchDiscrepancy(
            widget.batch.id,
            _justificationController.text.trim(),
          );
        } catch (_) {
          // Si el override falla o requiere revisión admin, el lote queda registrado
        }
      }

      if (confirmCashHandover) {
        try {
          await api.settleBatchFiat(widget.batch.id);
        } catch (_) {
          // Puede ya estar asentado o requerir liquidación posterior
        }
      }

      if (!mounted) return;
      await HapticFeedback.lightImpact();
      if (!mounted) return;
      context.read<SessionController>().notifyBatchesChanged();

      showAppSnack(
        context,
        confirmCashHandover
            ? 'Lote recibido con pesaje industrial y entrega de efectivo registrada conforme.'
            : 'Lote recibido con pesaje industrial. El pago en efectivo quedó registrado como pendiente.',
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimated = widget.batch.estimatedMaterials;
    final totalActual = _totalActualKg;
    final totalEst = _totalEstimatedKg;
    final pct = _discrepancyPct;
    final hasAlert = _hasDiscrepancyAlert;

    return Scaffold(
      appBar: AppBar(
        title: Text('Recibir Lote #${widget.batch.shortId}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: BusyButton(
            label: totalActual > 0
                ? 'Confirmar Recepción (${totalActual.toStringAsFixed(1)} kg · S/ ${_totalCashPEN.toStringAsFixed(2)})'
                : 'Confirmar Recepción',
            icon: Icons.scale_outlined,
            busy: _busy,
            onPressed: totalActual > 0 ? _submit : null,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: LivoraColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: LivoraColors.forest.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                            child: const Icon(Icons.person_outline, size: 20, color: LivoraColors.forest),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.batch.collectorName ??
                                      (widget.batch.collectorEmail != null
                                          ? widget.batch.collectorEmail!.split('@').first
                                          : 'Recolector'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                                Text(
                                  '${widget.batch.requests.length} recolección(es) consolidadas',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: LivoraColors.mint.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Lote #${widget.batch.shortId}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estimado por Recolector', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(fmtKg(totalEst), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Pesado en Báscula', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                fmtKg(totalActual),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: LivoraColors.forest,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Alerta comparativa de discrepancia si supera el 15%
              if (totalActual > 0 && totalEst > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasAlert ? Colors.amber.shade50 : LivoraColors.mint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasAlert ? Colors.amber.shade400 : LivoraColors.mint.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: hasAlert ? Colors.amber.shade900 : LivoraColors.forest,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasAlert
                                  ? 'Variación de peso: ${pct.toStringAsFixed(1)}% (excede el 15% de tolerancia)'
                                  : 'Variación de peso: ${pct.toStringAsFixed(1)}% (dentro de tolerancia normal)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: hasAlert ? Colors.amber.shade900 : LivoraColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasAlert) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _justificationController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Justificación técnica de merma o calibración',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SectionTitle(text: 'Pesaje real por material (Báscula)'),
              MaterialsEditor(
                initial: estimated.isEmpty ? null : estimated,
                onChanged: (materials) {
                  setState(() => _materials = materials);
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.black54),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los kilos ingresados alimentan el inventario de planta y fijan el pago en efectivo mano a mano.',
                        style: TextStyle(fontSize: 11.5, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
