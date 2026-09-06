import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../core/stellar.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import 'auction_bids_screen.dart';

/// Detalle de una solicitud de recolección (vista del HOGAR).
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  CollectionRequest? _request;
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final request = await context
          .read<LivoraApi>()
          .collectionRequestDetail(widget.requestId);
      if (mounted) {
        setState(() {
          _request = request;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la solicitud');
    }
  }

  Future<void> _cancel() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cancelar solicitud',
      message: '¿Seguro que deseas cancelar esta solicitud de recolección?',
      confirmLabel: 'Sí, cancelar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context
          .read<LivoraApi>()
          .updateCollectionStatus(widget.requestId, 'CANCELLED');
      if (mounted) {
        context.read<SessionController>().updateActiveRequest(null);
        showAppSnack(context, 'Solicitud cancelada');
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _selectBid(String bidId) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Aceptar propuesta',
      message:
          '¿Deseas asignar esta recolección a este centro de acopio con sus tarifas?',
      confirmLabel: 'Sí, aceptar',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<LivoraApi>().selectBid(widget.requestId, bidId);
      if (mounted) {
        showAppSnack(context, '¡Centro de acopio asignado con éxito!');
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    int rating = 5;
    final feedbackCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Calificar Servicio'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Cómo calificarías la atención y puntualidad del recolector?',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    iconSize: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(
                      starIndex <= rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFF59E0B),
                    ),
                    onPressed: submitting
                        ? null
                        : () => setDlgState(() => rating = starIndex),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Comentario opcional sobre el servicio...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setDlgState(() => submitting = true);
                      try {
                        await context.read<LivoraApi>().rateCollectionRequest(
                              widget.requestId,
                              rating: rating,
                              feedback: feedbackCtrl.text.trim().isNotEmpty
                                  ? feedbackCtrl.text.trim()
                                  : null,
                            );
                        if (!context.mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        showAppSnack(context, '¡Gracias por calificar el servicio!');
                        await _load();
                      } on ApiException catch (e) {
                        setDlgState(() => submitting = false);
                        if (context.mounted) showAppSnack(context, e.message, error: true);
                      } catch (_) {
                        setDlgState(() => submitting = false);
                        if (context.mounted) {
                          showAppSnack(context, 'Error al registrar calificación', error: true);
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final req = _request;
    if (req == null) return;

    final controllers = <String, TextEditingController>{};
    req.itemsEstimated.forEach((mat, wt) {
      controllers[mat] = TextEditingController(text: wt.toStringAsFixed(1));
    });
    final descCtrl = TextEditingController(text: req.description ?? '');
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: LivoraColors.forest),
              SizedBox(width: 8),
              Text('Editar Solicitud'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modifica los materiales o cantidades estimadas:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ...controllers.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: entry.value,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              suffixText: 'kg',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Notas o indicaciones:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Indicaciones actualizadas...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDlgState(() => saving = true);
                      final updatedItems = <String, double>{};
                      controllers.forEach((k, v) {
                        final parsed = double.tryParse(v.text.replaceAll(',', '.')) ?? 0;
                        if (parsed > 0) updatedItems[k] = parsed;
                      });

                      try {
                        await context.read<LivoraApi>().editCollectionRequest(
                              widget.requestId,
                              itemsEstimated: updatedItems,
                              description: descCtrl.text.trim(),
                            );
                        if (!context.mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        showAppSnack(context, 'Solicitud actualizada con éxito');
                        await _load();
                      } on ApiException catch (e) {
                        setDlgState(() => saving = false);
                        if (e.statusCode == 409 || e.message.contains('ya está en curso')) {
                          if (!context.mounted) return;
                          if (ctx.mounted) Navigator.pop(ctx);
                          await showDialog(
                            context: context,
                            builder: (alertCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
                                  SizedBox(width: 8),
                                  Text('No se puede modificar'),
                                ],
                              ),
                              content: const Text(
                                'Tu solicitud ya está en curso y no puede ser modificada',
                                style: TextStyle(fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(alertCtx),
                                  child: const Text('Entendido'),
                                ),
                              ],
                            ),
                          );
                          await _load();
                        } else {
                          if (context.mounted) showAppSnack(context, e.message, error: true);
                        }
                      } catch (_) {
                        setDlgState(() => saving = false);
                        if (context.mounted) {
                          showAppSnack(context, 'Error al actualizar la solicitud', error: true);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de solicitud'),
        actions: [
          if (request != null && request.status == 'PENDING')
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Editar solicitud',
              onPressed: _showEditDialog,
            ),
        ],
      ),
      body: _error != null
          ? EmptyState(
              icon: Icons.cloud_off,
              title: 'No se pudo cargar la solicitud',
              message: _error,
            )
          : request == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          StatusChip(
                            label: requestStatusLabel(request.status),
                            color: requestStatusColor(request.status),
                          ),
                          const SizedBox(width: 8),
                          if (request.assignmentMode == 'AUCTION')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.indigo.shade200,
                                ),
                              ),
                              child: const Text(
                                'Subasta',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            fmtDate(request.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: LivoraColors.ink.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Fotografía con miniatura expandible
                      if (request.photoUrl != null) ...[
                        GestureDetector(
                          onTap: () => _showImageDialog(request.photoUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: request.photoUrl!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 800,
                                  memCacheHeight: 600,
                                  placeholder: (context, url) => Container(
                                    height: 180,
                                    color: LivoraColors.forest.withValues(alpha: 0.08),
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 180,
                                    color: LivoraColors.paper,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined, size: 36),
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ver foto completa',
                                        style: TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // PIN de Verificación en Cajas OTP
                      if (request.status == 'PENDING' ||
                          request.status == 'ACCEPTED') ...[
                        Card(
                          color: LivoraColors.blue.withValues(alpha: 0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: LivoraColors.blue, width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.key_rounded, color: LivoraColors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'PIN DE VERIFICACIÓN',
                                      style: TextStyle(
                                        color: LivoraColors.deep,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                OtpPinBox(
                                  pin: request.verificationPin ?? '----',
                                  isActive: true,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Dicta este PIN de 4 dígitos a tu recolector al momento de entregar los materiales.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: LivoraColors.ink,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Enlace Web3 Stellar Expert (si está confirmada en blockchain)
                      if (request.txHash != null && Stellar.isValidTxHash(request.txHash)) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: LivoraColors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: LivoraColors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_outlined, color: LivoraColors.blue, size: 22),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Certificado en Stellar Blockchain',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: LivoraColors.deep,
                                      ),
                                    ),
                                    Text(
                                      'Transacción inmutable y verificable',
                                      style: TextStyle(fontSize: 11, color: LivoraColors.ink),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => Stellar.openTxInExplorer(request.txHash),
                                icon: const Icon(Icons.open_in_new, size: 14),
                                label: const Text('Ver en Explorer', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Ofertas en Modo Subasta
                      if (request.assignmentMode == 'AUCTION' &&
                          request.bids.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SectionTitle(text: 'Ofertas de Acopio (${request.bids.length})'),
                            TextButton.icon(
                              onPressed: () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AuctionBidsScreen(request: request),
                                  ),
                                );
                                if (updated == true) _load();
                              },
                              icon: const Icon(Icons.fullscreen, size: 16),
                              label: const Text('Ver pantalla completa', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        for (final bid in request.bids)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: bid.status == 'ACCEPTED'
                                    ? LivoraColors.green
                                    : Colors.grey.shade300,
                                width: bid.status == 'ACCEPTED' ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: LivoraColors.paper,
                                        child: Icon(
                                          Icons.storefront,
                                          size: 16,
                                          color: LivoraColors.deep,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          sanitizedPersonName(
                                            bid.centerName,
                                            bid.centerEmail,
                                            defaultLabel: 'Centro de Acopio',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (bid.status == 'ACCEPTED')
                                        const StatusChip(
                                          label: 'Aceptada',
                                          color: LivoraColors.green,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tarifas ofrecidas por kg: ${bid.proposedRates.entries.map((e) => '${materialLabel(e.key)}: S/ ${e.value.toStringAsFixed(2)}').join(' · ')}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Tu ganancia estimada (40%):',
                                          style: TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                        Text(
                                          '${bid.totalEstimatedEco.toStringAsFixed(2)} ECO (≈ S/ ${bid.totalEstimatedEco.toStringAsFixed(2)})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: LivoraColors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (bid.status != 'ACCEPTED' &&
                                      (request.status == 'PENDING' ||
                                          request.status == 'AUCTION_OPEN')) ...[
                                    const SizedBox(height: 10),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                                      onPressed: () => _selectBid(bid.id),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Aceptar esta oferta'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // Materiales Estimados vs Reales
                      const SectionTitle(text: 'Materiales y Pesajes'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              for (final entry in request.itemsEstimated.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.recycling, size: 18, color: LivoraColors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          materialLabel(entry.key),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: LivoraColors.deep,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Est: ${fmtKg(entry.value)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: LivoraColors.ink,
                                            ),
                                          ),
                                          if (request.actualWeights != null &&
                                              request.actualWeights![entry.key] != null) ...[
                                            Text(
                                              'Real: ${fmtKg(request.actualWeights![entry.key])}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: LivoraColors.forest,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 12),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total estimado',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    fmtKg(request.totalEstimatedKg),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ],
                              ),
                              if (request.actualWeights != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total real en planta',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: LivoraColors.forest,
                                      ),
                                    ),
                                    Text(
                                      fmtKg(request.totalActualKg),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: LivoraColors.forest,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Información del Servicio
                      const SectionTitle(text: 'Información del Servicio'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              InfoRow(
                                label: 'Recolector asignado',
                                value: sanitizedPersonName(
                                  request.collectorName,
                                  request.collectorEmail,
                                  defaultLabel: 'Aún sin asignar',
                                ),
                              ),
                              if (request.assignedCenterName != null ||
                                  request.assignedCenterEmail != null)
                                InfoRow(
                                  label: 'Centro de Acopio',
                                  value: sanitizedPersonName(
                                    request.assignedCenterName,
                                    request.assignedCenterEmail,
                                    defaultLabel: 'Centro de Acopio',
                                  ),
                                ),
                              InfoRow(
                                label: 'Ganancia estimada Hogar',
                                value: request.hogarEstimatedEarningsPEN > 0
                                    ? '≈ S/ ${request.hogarEstimatedEarningsPEN.toStringAsFixed(2)} PEN (40%)'
                                    : 'A liquidar en pesaje',
                              ),
                              InfoRow(
                                label: 'Notas',
                                value: request.description?.isNotEmpty == true
                                    ? request.description!
                                    : '—',
                              ),
                              InfoRow(
                                label: 'Dirección de recojo',
                                value: request.householdAddress?.isNotEmpty == true
                                    ? request.householdAddress!
                                    : (context.read<SessionController>().user?.address?.isNotEmpty == true
                                        ? context.read<SessionController>().user!.address!
                                        : 'Ubicación física registrada vía GPS'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Calificación del Servicio (COMPLETED)
                      if (request.status == 'COMPLETED') ...[
                        Card(
                          color: const Color(0xFFFFFBEB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      request.rating != null
                                          ? 'Servicio Calificado'
                                          : '¿Cómo estuvo la recolección?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (request.rating != null) ...[
                                  Row(
                                    children: [
                                      ...List.generate(5, (i) => Icon(
                                        i < request.rating! ? Icons.star : Icons.star_border,
                                        color: const Color(0xFFF59E0B),
                                        size: 20,
                                      )),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${request.rating} / 5)',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  if (request.feedback?.isNotEmpty == true) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '"${request.feedback}"',
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ] else ...[
                                  const Text(
                                    'Tu opinión ayuda a mejorar la reputación del recolector y mantener la calidad del servicio.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF59E0B),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 44),
                                    ),
                                    onPressed: _showRatingDialog,
                                    icon: const Icon(Icons.star_rate),
                                    label: const Text('Calificar Recolector'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Botón para editar materiales en PENDING
                      if (request.status == 'PENDING') ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LivoraColors.forest,
                            side: const BorderSide(color: LivoraColors.forest),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: _showEditDialog,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Editar materiales de la solicitud'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Cancelación
                      if (request.status == 'PENDING' ||
                          request.status == 'ACCEPTED' ||
                          request.status == 'AUCTION_OPEN')
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8C3A3A),
                            side: const BorderSide(color: Color(0xFF8C3A3A)),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: _cancelling ? null : _cancel,
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(
                            _cancelling ? 'Cancelando…' : 'Cancelar solicitud',
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
