import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/formats.dart';
import '../core/session.dart';
import '../core/stellar.dart';
import '../models/models.dart';
import '../services/livora_api.dart';
import 'common.dart';

/// Modal BottomSheet de Recibo Digital para visualizar el detalle de un lote entregado en el historial.
class BatchDetailModal extends StatelessWidget {
  const BatchDetailModal({super.key, required this.batch});

  final Batch batch;

  static Future<bool?> show(BuildContext context, {required Batch batch}) async {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BatchDetailModal(batch: batch),
    );
  }

  Future<void> _openStellarExpert(BuildContext context, String txHash) async {
    HapticFeedback.lightImpact();
    final url = Uri.parse('https://stellar.expert/explorer/testnet/tx/$txHash');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showAppSnack(context, 'No se pudo abrir el explorador de Stellar', error: true);
        }
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Error al abrir Stellar Expert', error: true);
      }
    }
  }

  void _copyTxHash(BuildContext context, String txHash) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: txHash));
    showAppSnack(context, 'Hash de transacción copiado al portapapeles');
  }

  Future<void> _settleFiat(BuildContext context) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Confirmar Pago Fiat',
      message:
          '¿Confirmas que se ha realizado la entrega del pago en efectivo o transferencia en soles (PEN) al recolector por los materiales de este lote?',
      confirmLabel: 'Sí, marcar como pagado',
      cancelLabel: 'Cancelar',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await context.read<LivoraApi>().settleBatchFiat(batch.id);
      if (context.mounted) {
        showAppSnack(context, 'Pago fiat registrado exitosamente');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (context.mounted) showAppSnack(context, 'Error al registrar el pago fiat', error: true);
    }
  }

  Future<void> _disputeBatch(BuildContext context) async {
    final reasonController = TextEditingController();
    final shouldDispute = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.shield_outlined, color: LivoraColors.coral, size: 36),
        title: const Text('Impugnar Pesaje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Si el pesaje registrado en planta difiere sustancialmente de tu carga, describe detalladamente la discrepancia para que administración intervenga:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo de la impugnación',
                hintText: 'Ej. Se entregaron 3 fardos de 45 kg pesados previamente...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LivoraColors.coral),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(dialogCtx, true);
            },
            child: const Text('Enviar Disputa'),
          ),
        ],
      ),
    );

    if (shouldDispute != true || !context.mounted) return;

    try {
      await context.read<LivoraApi>().disputeBatch(batch.id, reasonController.text.trim());
      if (context.mounted) {
        showAppSnack(context, 'Disputa iniciada. El lote ha pasado a estado EN DISPUTA para arbitraje.');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (context.mounted) showAppSnack(context, 'Error al iniciar la disputa', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final userRole = session.user?.role;
    final isAcopio = userRole == Roles.centroAcopio;
    final isRecolector = userRole == Roles.recolector;

    final centerLabel = sanitizedCenterName(
      batch.destinationCenterName,
      batch.destinationCenterEmail,
      defaultLabel: 'Centro de Acopio Autorizado',
    );

    final estimatedTotals = batch.estimatedMaterials;
    final actualTotals = batch.materialsActual ?? {};

    // Conjunto de todos los materiales involucrados
    final allMaterials = <String>{...estimatedTotals.keys, ...actualTotals.keys};

    final totalEstimatedKg = batch.requests.fold<double>(
      0.0,
      (sum, r) => sum + r.totalEstimatedKg,
    );
    final totalActualKg = batch.totalActualKg;

    final txHash = batch.txHash;
    final hasValidTx = txHash != null && Stellar.isValidTxHash(txHash);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (sheetContext, scrollController) => Column(
        children: [
          // Tirador táctil (Drag Handle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                // Cabecera de Estado
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                      child: const Icon(Icons.inventory_2_outlined, color: LivoraColors.forest, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lote #${batch.shortId}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: LivoraColors.deep,
                            ),
                          ),
                          Text(
                            'Recibido: ${fmtDate(batch.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: LivoraColors.ink.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: batchStatusLabel(batch.status),
                      color: batchStatusColor(batch.status),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ficha del Centro de Acopio Sanitizada
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: LivoraColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: LivoraColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.warehouse_rounded, color: LivoraColors.blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Planta de Destino / Acopio',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: LivoraColors.blue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              centerLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.deep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tabla Comparativa de Pesaje: Estimado vs Real Báscula
                const SectionTitle(text: 'Pesaje Comparativo en Báscula'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LivoraColors.border),
                  ),
                  child: Column(
                    children: [
                      // Encabezado de columnas
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          color: LivoraColors.paper,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Material',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LivoraColors.deep),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Estimado',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LivoraColors.ink),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Real Báscula',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LivoraColors.forest),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filas por material
                      if (allMaterials.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No hay detalle de pesaje disponible.',
                            style: TextStyle(fontSize: 12, color: LivoraColors.ink),
                          ),
                        )
                      else
                        for (final mat in allMaterials)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.recycling_rounded, size: 15, color: LivoraColors.forest),
                                      const SizedBox(width: 6),
                                      Text(
                                        materialLabel(mat),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: LivoraColors.deep,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    fmtKg(estimatedTotals[mat] ?? 0.0),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12.5, color: LivoraColors.ink),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    fmtKg(actualTotals[mat] ?? 0.0),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: LivoraColors.forest,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                      const Divider(height: 1),

                      // Fila Total
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'Total consolidado',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: LivoraColors.deep),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                fmtKg(totalEstimatedKg),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LivoraColors.ink),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                fmtKg(totalActualKg > 0 ? totalActualKg : totalEstimatedKg),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: LivoraColors.forest,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (batch.status == 'FLAGGED_FOR_REVIEW') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: LivoraColors.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: LivoraColors.coral.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: LivoraColors.coral, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lote con Discrepancia Observada (>15%)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: LivoraColors.coral,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (batch.discrepancyNote != null && batch.discrepancyNote!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            batch.discrepancyNote!,
                            style: const TextStyle(fontSize: 12, color: LivoraColors.deep),
                          ),
                        ],
                        if (isRecolector) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: LivoraColors.coral,
                                side: const BorderSide(color: LivoraColors.coral),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _disputeBatch(context),
                              icon: const Icon(Icons.shield_outlined, size: 16),
                              label: const Text(
                                'Impugnar Pesaje (Disputa B2B)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (batch.status == 'DISPUTED') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gavel_rounded, color: Colors.purple.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lote en Arbitraje Administrativo B2B',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Colors.purple.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'El recolector ha impugnado formalmente el pesaje de este lote. El equipo legal y de operaciones está revisando el caso.',
                          style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                        ),
                        if (batch.disputeReason != null && batch.disputeReason!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.shade100),
                            ),
                            child: Text(
                              'Motivo: ${batch.disputeReason}',
                              style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (batch.status == 'RECEIVED' || batch.status == 'CONSOLIDATED') ...[
                  const SectionTitle(text: 'Liquidación Contable Dual (Fiat / Soles)'),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: batch.fiatSettled ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: batch.fiatSettled ? Colors.green.shade200 : Colors.amber.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              batch.fiatSettled ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                              color: batch.fiatSettled ? LivoraColors.green : Colors.amber.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                batch.fiatSettled ? 'Pago Fiat Liquidado' : 'Pago Fiat Pendiente',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: batch.fiatSettled ? LivoraColors.forest : Colors.amber.shade900,
                                ),
                              ),
                            ),
                            StatusChip(
                              label: batch.fiatSettled ? 'PAGADO' : 'PENDIENTE',
                              color: batch.fiatSettled ? LivoraColors.green : Colors.amber.shade800,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          batch.fiatSettled
                              ? 'La liquidación física en soles (PEN) fue confirmada por el centro de acopio${batch.fiatSettledAt != null ? ' el ${fmtDate(batch.fiatSettledAt)}' : ''}.'
                              : 'La entrega de soles en efectivo o por transferencia al recolector aún no ha sido marcada como completada.',
                          style: TextStyle(
                            fontSize: 12,
                            color: batch.fiatSettled ? Colors.green.shade900 : Colors.brown.shade800,
                          ),
                        ),
                        if (!batch.fiatSettled && isAcopio) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: LivoraColors.forest,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _settleFiat(context),
                              icon: const Icon(Icons.payments_outlined, size: 18),
                              label: const Text(
                                'Marcar Pago Fiat Realizado',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tarjeta de Trazabilidad Blockchain (Stellar Expert)
                const SectionTitle(text: 'Trazabilidad en Stellar / Soroban'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hub_outlined, color: LivoraColors.cyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Comprobante Inmutable en Blockchain',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (hasValidTx) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Tx: ${Stellar.short(txHash)}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: LivoraColors.paper,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar Hash',
                              icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                              onPressed: () => _copyTxHash(context, txHash),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: LivoraColors.cyan,
                              foregroundColor: LivoraColors.deep,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _openStellarExpert(context, txHash),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text(
                              'Ver Comprobante en Stellar Expert',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Liquidación contable interna. Registro on-chain en proceso de notarización.',
                                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de Recolecciones Consolidadas en el Lote
                Text(
                  'Recolecciones incluidas (${batch.requests.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: LivoraColors.deep,
                  ),
                ),
                const SizedBox(height: 8),
                for (final req in batch.requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: LivoraColors.paper,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: LivoraColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: LivoraColors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sanitizedPersonName(req.householdName, req.householdEmail, defaultLabel: 'Hogar'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LivoraColors.deep),
                                ),
                                Text(
                                  materialsSummary(req.itemsEstimated),
                                  style: const TextStyle(fontSize: 11, color: LivoraColors.ink),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            fmtKg(req.totalEstimatedKg),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LivoraColors.deep),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // BOTÓN DE CIERRE
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LivoraColors.forest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: const Text('Cerrar Recibo', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
