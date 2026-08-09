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
      title: 'Confirmar recepción',
      message:
          'Se registrará el pesaje real y se iniciará la liquidación de incentivos en blockchain. Esta acción no se puede repetir.',
      confirmLabel: 'Recibir lote',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await context
          .read<LivoraApi>()
          .receiveBatch(widget.batch.id, _materials);
      if (!mounted) return;
      showAppSnack(
        context,
        'Recepción registrada. El pago de EcoTokens se procesa en segundo plano.',
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
                        value: widget.batch.collectorEmail ?? '—',
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
