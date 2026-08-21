import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/common.dart';
import '../common/profile.dart';
import '../common/qr_scanner_view.dart';

/// Lote abierto del recolector + historial de lotes.
class MyBatchScreen extends StatefulWidget {
  const MyBatchScreen({super.key});

  @override
  State<MyBatchScreen> createState() => _MyBatchScreenState();
}

class _MyBatchScreenState extends State<MyBatchScreen> {
  Batch? _openBatch;
  List<Batch>? _history;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<LivoraApi>();
    try {
      final results = await Future.wait([api.openBatch(), api.batches()]);
      if (!mounted) return;
      setState(() {
        _openBatch = results[0] as Batch;
        _history = (results[1] as List<Batch>)
            .where((batch) => batch.status != 'OPEN')
            .toList();
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _sendToCenter() async {
    final batch = _openBatch;
    if (batch == null) return;

    final controller = TextEditingController();
    final centerId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar al centro de acopio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: livoraInput(
                      'ID del centro de acopio',
                      hint: 'UUID del centro',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: LivoraColors.forest),
                  tooltip: 'Escanear código QR',
                  onPressed: () async {
                    final scanned = await Navigator.push<String>(
                      dialogContext,
                      MaterialPageRoute(builder: (_) => const QRScannerView()),
                    );
                    if (scanned != null && scanned.isNotEmpty) {
                      controller.text = scanned;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pídele al centro su "ID de usuario" o escanea su código QR desde su perfil.',
              style: TextStyle(fontSize: 12, color: LivoraColors.ink),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (centerId == null || centerId.isEmpty || !mounted) return;

    setState(() => _sending = true);
    try {
      await context.read<LivoraApi>().sendBatchToCenter(batch.id, centerId);
      if (mounted) {
        showAppSnack(
          context,
          'Lote en tránsito. Entrégalo en el centro de acopio para el pesaje.',
        );
        _load();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyPin(CollectionRequest request) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar PIN del Hogar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Solicita al ciudadano el PIN de 4 dígitos que aparece en su pantalla para confirmar la recogida física.',
              style: TextStyle(fontSize: 12.5, color: LivoraColors.ink),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: livoraInput('PIN de 4 dígitos', hint: 'Ej. 1234'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (pin == null || pin.isEmpty || !mounted) return;

    try {
      await context.read<LivoraApi>().verifyCollectionRequest(request.id, pin);
      if (mounted) {
        showAppSnack(context, 'Recolección confirmada con éxito');
        _load();
      }
    } on ApiException catch (error) {
      final errStr = error.message.toLowerCase();
      if (errStr.contains('no se pudo conectar') || errStr.contains('servidor no respondió')) {
        await OfflineQueueManager.enqueueVerification(request.id, pin);
        if (mounted) {
          showAppSnack(
            context,
            'Sin conexión. La verificación se guardó localmente y se sincronizará al recuperar internet.',
          );
          setState(() {
            request.status = 'COMPLETED';
          });
        }
      } else {
        if (mounted) showAppSnack(context, error.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = _openBatch;
    final history = _history;

    return Scaffold(
      appBar: livoraAppBar(context, 'Mi lote'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                title: 'No se pudo cargar tu lote',
                message: _error,
              )
            else if (batch == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Lote #${batch.shortId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
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
                      const SizedBox(height: 4),
                      Text(
                        batch.requests.isEmpty
                            ? 'Acepta solicitudes en la pestaña "Solicitudes" para llenar este lote.'
                            : '${batch.requests.length} recolección(es) · '
                                'Estimado: ${fmtKg(batch.requests.fold(0.0, (sum, r) => sum + r.totalEstimatedKg))}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: LivoraColors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final request in batch.requests)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: LivoraColors.paper,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.between,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request.householdEmail ?? 'Hogar',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: LivoraColors.deep,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        materialsSummary(request.itemsEstimated),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: LivoraColors.ink,
                                        ),
                                      ),
                                      Text(
                                        '${request.latitude.toStringAsFixed(4)}, '
                                        '${request.longitude.toStringAsFixed(4)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: LivoraColors.ink
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (request.status == 'ACCEPTED')
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: LivoraColors.forest,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () => _verifyPin(request),
                                    icon: const Icon(Icons.pin_outlined, size: 16),
                                    label: const Text(
                                      'Confirmar PIN',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (request.status == 'COMPLETED')
                                  const Icon(
                                    Icons.check_circle,
                                    color: LivoraColors.green,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (batch.requests.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        BusyButton(
                          label: 'Enviar al centro de acopio',
                          icon: Icons.local_shipping_outlined,
                          busy: _sending,
                          onPressed: _sendToCenter,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle(text: 'Historial de lotes'),
              if (history == null || history.isEmpty)
                const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Sin lotes anteriores',
                  message:
                      'Cuando envíes lotes al centro de acopio aparecerán aquí.',
                )
              else
                for (final item in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        title: Text(
                          'Lote #${item.shortId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: LivoraColors.deep,
                          ),
                        ),
                        subtitle: Text(
                          '${item.destinationCenterEmail ?? 'Centro sin asignar'}'
                          '\n${fmtDate(item.createdAt)}'
                          '${item.materialsActual != null ? ' · Pesaje real: ${fmtKg(item.totalActualKg)}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: StatusChip(
                          label: batchStatusLabel(item.status),
                          color: batchStatusColor(item.status),
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
