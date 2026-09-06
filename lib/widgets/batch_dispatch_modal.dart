import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/formats.dart';
import '../models/models.dart';
import '../screens/common/qr_scanner_view.dart';
import '../services/livora_api.dart';
import 'common.dart';

/// Modal interactivo de despacho y entrega de lote en planta de acopio.
/// Soporta dos opciones:
/// 1. Mostrar QR del Lote para que el operador de planta lo escanee con su lector.
/// 2. Escanear el código QR del Centro de Acopio para despachar y cambiar a IN_TRANSIT.
class BatchDispatchModal extends StatefulWidget {
  const BatchDispatchModal({
    super.key,
    required this.batch,
  });

  final Batch batch;

  static Future<bool?> show(BuildContext context, {required Batch batch}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BatchDispatchModal(batch: batch),
    );
  }

  @override
  State<BatchDispatchModal> createState() => _BatchDispatchModalState();
}

class _BatchDispatchModalState extends State<BatchDispatchModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _centerIdController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.batch.destinationCenterId != null) {
      _centerIdController.text = widget.batch.destinationCenterId!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _centerIdController.dispose();
    super.dispose();
  }

  Future<void> _dispatchToCenter(String centerId) async {
    final cleanId = centerId.trim();
    if (cleanId.isEmpty) return;

    if (widget.batch.destinationCenterId != null &&
        widget.batch.destinationCenterId!.isNotEmpty &&
        widget.batch.destinationCenterId != cleanId) {
      showAppSnack(
        context,
        'Este sub-lote está asignado al centro ${widget.batch.destinationCenterName ?? widget.batch.destinationCenterId}. El QR escaneado pertenece a otro centro.',
        error: true,
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await context.read<LivoraApi>().sendBatchToCenter(widget.batch.id, cleanId);
      if (mounted) {
        showAppSnack(
          context,
          'Lote despachado en tránsito hacia el Centro de Acopio para pesaje.',
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, error.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _scanCenterQr() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerView()),
    );
    if (scanned != null && scanned.trim().isNotEmpty) {
      _centerIdController.text = scanned.trim();
      await _dispatchToCenter(scanned.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final totalKg = batch.requests.fold<double>(
      0.0,
      (sum, r) => sum + r.totalEstimatedKg,
    );
    final materials = batch.estimatedMaterials;

    // Payload de alta densidad para lectores QR de planta
    final qrPayload = jsonEncode({
      'type': 'LIVORA_BATCH',
      'batchId': batch.id,
      'shortId': batch.shortId,
      'destinationCenterId': batch.destinationCenterId,
      'totalKg': totalKg,
    });

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tirador decorativo
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Título y Subtítulo
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                child: const Icon(Icons.warehouse_rounded, color: LivoraColors.forest, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entregar Lote #${batch.shortId}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    Text(
                      '${batch.requests.length} recolección(es) · ${fmtKg(totalKg)} acumulados',
                      style: const TextStyle(fontSize: 12, color: LivoraColors.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pestañas Dobles de Selección
          Container(
            decoration: BoxDecoration(
              color: LivoraColors.paper,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: LivoraColors.deep,
              unselectedLabelColor: LivoraColors.ink.withValues(alpha: 0.6),
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(
                  icon: Icon(Icons.qr_code_2, size: 20),
                  text: 'Mostrar QR del Lote',
                ),
                Tab(
                  icon: Icon(Icons.qr_code_scanner, size: 20),
                  text: 'Escanear QR Acopio',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contenido de las pestañas
          SizedBox(
            height: 310,
            child: TabBarView(
              controller: _tabController,
              children: [
                // PESTAÑA 1: Mostrar QR del Lote
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        'Muestra este código al operario del Centro de Acopio al ingresar a la planta:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: LivoraColors.ink),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: LivoraColors.border, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 160,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: LivoraColors.deep,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: LivoraColors.deep,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Resumen de materiales acumulados
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: materials.entries.map((e) {
                          return Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              '${materialLabel(e.key)}: ${fmtKg(e.value)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: LivoraColors.forest.withValues(alpha: 0.08),
                            side: BorderSide(color: LivoraColors.forest.withValues(alpha: 0.2)),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // PESTAÑA 2: Escanear QR del Acopio
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        'Escanea el código QR de recepción ubicado en la entrada de la planta o mostrado por el encargado:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: LivoraColors.ink),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: LivoraColors.forest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _sending ? null : _scanCenterQr,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text(
                          'Abrir Cámara para Escanear',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('o ingresa el ID manualmente', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _centerIdController,
                              decoration: livoraInput(
                                'ID del Centro de Acopio',
                                hint: 'UUID del centro',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(80, 48),
                              backgroundColor: LivoraColors.deep,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _sending
                                ? null
                                : () => _dispatchToCenter(_centerIdController.text),
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Enviar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Botón de Cierre
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
