import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/materials_editor.dart';

/// Pesaje industrial del lote al recibirlo en el centro de acopio.
class ReceiveBatchScreen extends StatefulWidget {
  const ReceiveBatchScreen({super.key, required this.batch});

  final Batch batch;

  @override
  State<ReceiveBatchScreen> createState() => _ReceiveBatchScreenState();
}

class _ReceiveBatchScreenState extends State<ReceiveBatchScreen> {
  Map<String, double> _materials = {};
  bool _busy = false;

  Future<bool> _showResolveDiscrepancyDialog(String batchId) async {
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
          title: const Text('Resolver Discrepancia'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ingresa la justificación técnica para autorizar este lote y encolarlo al procesamiento blockchain:',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nota de justificación',
                    hintText: 'Ej. Tolerancia aceptada por merma de humedad...',
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
                              batchId,
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
                  : const Text('Autorizar Lote'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    return resolved ?? false;
  }

  Future<void> _submit() async {
    if (_materials.isEmpty) {
      showAppSnack(
        context,
        'Registra el peso real de al menos un material',
        error: true,
      );
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: 'Confirmar recepción en planta',
      message:
          'Se registrará el pesaje industrial para control de inventario y certificación ESG. Recuerda realizar la liquidación en efectivo físico al recolector según tu tarifario.',
      confirmLabel: 'Recibir lote',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final res = await context
          .read<LivoraApi>()
          .receiveBatch(widget.batch.id, _materials);
      if (!mounted) return;

      final isFlagged = res['status'] == 'FLAGGED_FOR_REVIEW' ||
          res['hasDiscrepancy'] == true;

      if (isFlagged) {
        final discrepancyNote = res['discrepancyNote'] as String? ??
            'La diferencia entre el peso estimado y el pesado real excede el 15%.';

        final action = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: LivoraColors.amber,
              size: 44,
            ),
            title: const Text('Lote Observado por Discrepancia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'El pesaje industrial difiere significativamente del estimado por el recolector. El lote ha sido retenido en estado "Observado" sin minteo automático.',
                  style: TextStyle(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: LivoraColors.amber.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    discrepancyNote,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: LivoraColors.deep,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, 'OBSERVADOS'),
                child: const Text('Ver en Observados'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                ),
                onPressed: () => Navigator.pop(dialogCtx, 'RESOLVER'),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Resolver ahora'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (action == 'RESOLVER') {
          final resolved =
              await _showResolveDiscrepancyDialog(widget.batch.id);
          if (resolved && mounted) {
            showAppSnack(
              context,
              'Discrepancia autorizada. Lote enviado a procesamiento blockchain.',
            );
            Navigator.pop(context, true);
          } else if (mounted) {
            Navigator.pop(context, 'FLAGGED_FOR_REVIEW');
          }
        } else {
          Navigator.pop(context, 'FLAGGED_FOR_REVIEW');
        }
        return;
      }

      showAppSnack(
        context,
        'Lote recibido exitosamente. Notarización ESG en proceso y liquidación en efectivo al recolector confirmada.',
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Recibir lote #${widget.batch.shortId}'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoRow(
                        label: 'Recolector',
                        value: widget.batch.collectorName ??
                            (widget.batch.collectorEmail != null
                                ? widget.batch.collectorEmail!.split('@').first
                                : '—'),
                      ),
                      InfoRow(
                        label: 'Recolecciones',
                        value: '${widget.batch.requests.length}',
                      ),
                      InfoRow(
                        label: 'Estimado',
                        value: estimated.isEmpty
                            ? '—'
                            : materialsSummary(estimated),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SectionTitle(text: 'Pesaje real (báscula industrial)'),
              MaterialsEditor(
                initial: estimated.isEmpty ? null : estimated,
                onChanged: (materials) => _materials = materials,
              ),
              const SizedBox(height: 8),
              Text(
                'Ajusta los pesos según la báscula. Con estos valores se '
                'liquidarán los EcoTokens de hogares y recolector.',
                style: TextStyle(
                  fontSize: 12,
                  color: LivoraColors.ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              BusyButton(
                label: 'Confirmar recepción',
                icon: Icons.scale_outlined,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
