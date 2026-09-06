import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

/// Pantalla dedicada para que el Hogar compare las propuestas de tarifas
/// enviadas por los Centros de Acopio en modo Subasta y elija la más conveniente.
class AuctionBidsScreen extends StatefulWidget {
  const AuctionBidsScreen({super.key, required this.request});

  final CollectionRequest request;

  @override
  State<AuctionBidsScreen> createState() => _AuctionBidsScreenState();
}

class _AuctionBidsScreenState extends State<AuctionBidsScreen> {
  late CollectionRequest _request;
  bool _loading = false;
  String? _selectingBidId;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _refreshRequest();
  }

  Future<void> _refreshRequest() async {
    setState(() => _loading = true);
    try {
      final req = await context
          .read<LivoraApi>()
          .collectionRequestDetail(_request.id);
      if (mounted) {
        setState(() {
          _request = req;
          _loading = false;
        });
        context.read<SessionController>().updateActiveRequest(req);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectBid(AcopioBid bid) async {
    final centerName = sanitizedPersonName(
      bid.centerName,
      bid.centerEmail,
      defaultLabel: 'Centro de Acopio',
    );

    final confirmed = await confirmDialog(
      context,
      title: 'Aceptar propuesta de subasta',
      message: '¿Deseas aceptar la oferta de "$centerName"? '
          'Recibirás ≈ S/ ${bid.totalEstimatedEco.toStringAsFixed(2)} PEN (40%) '
          'y se asignará un recolector a tu domicilio.',
      confirmLabel: 'Aceptar oferta',
    );
    if (!confirmed || !mounted) return;

    setState(() => _selectingBidId = bid.id);
    try {
      await context.read<LivoraApi>().selectBid(_request.id, bid.id);
      if (mounted) {
        showAppSnack(context, '¡Oferta aceptada! El centro de acopio ha sido asignado.');
        await _refreshRequest();
        if (mounted) Navigator.pop(context, true);
      }
    } on ApiException catch (err) {
      if (mounted) showAppSnack(context, err.message, error: true);
    } finally {
      if (mounted) setState(() => _selectingBidId = null);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cancelar subasta',
      message: '¿Seguro que deseas cancelar esta solicitud en subasta? '
          'Las ofertas recibidas quedarán sin efecto.',
      confirmLabel: 'Sí, cancelar subasta',
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context
          .read<LivoraApi>()
          .updateCollectionStatus(_request.id, 'CANCELLED');
      if (mounted) {
        context.read<SessionController>().updateActiveRequest(null);
        showAppSnack(context, 'Subasta cancelada correctamente');
        Navigator.pop(context, true);
      }
    } on ApiException catch (err) {
      if (mounted) showAppSnack(context, err.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bids = _request.bids;
    final isAuctionOpen = _request.status == 'PENDING' || _request.status == 'AUCTION_OPEN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas de Acopio'),
        actions: [
          IconButton(
            tooltip: 'Actualizar ofertas',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRequest,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Resumen de la Solicitud
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.indigo.withValues(alpha: 0.25), width: 1.2),
                    ),
                    color: Colors.indigo.shade50.withValues(alpha: 0.4),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.gavel, size: 14, color: Colors.indigo),
                                    SizedBox(width: 4),
                                    Text(
                                      'Mesa de Subasta',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                fmtDate(_request.createdAt),
                                style: const TextStyle(fontSize: 11.5, color: LivoraColors.slate),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            materialsSummary(_request.itemsEstimated),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.deep,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Compara las tarifas que los centros de acopio ofrecen por tus materiales. '
                            'El 40% del valor total se abona directamente a tu billetera.',
                            style: TextStyle(
                              fontSize: 12,
                              color: LivoraColors.ink.withValues(alpha: 0.75),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SectionTitle(text: 'Propuestas Recibidas (${bids.length})'),
                  const SizedBox(height: 6),

                  if (bids.isEmpty)
                    const EmptyState(
                      icon: Icons.hourglass_top_outlined,
                      title: 'Esperando propuestas',
                      message:
                          'Tu solicitud está visible para los centros de acopio autorizados. '
                          'Te notificaremos en cuanto recibas ofertas de tarifas.',
                    )
                  else
                    for (final bid in bids)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: bid.status == 'ACCEPTED'
                                ? LivoraColors.green
                                : LivoraColors.border,
                            width: bid.status == 'ACCEPTED' ? 1.8 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cabecera del Centro de Acopio
                              Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: LivoraColors.paper,
                                    child: Icon(
                                      Icons.storefront,
                                      size: 18,
                                      color: LivoraColors.deep,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sanitizedPersonName(
                                            bid.centerName,
                                            bid.centerEmail,
                                            defaultLabel: 'Centro de Acopio',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.5,
                                            color: LivoraColors.deep,
                                          ),
                                        ),
                                        if (bid.centerAddress != null && bid.centerAddress!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            bid.centerAddress!,
                                            style: const TextStyle(fontSize: 11, color: LivoraColors.slate),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (bid.status == 'ACCEPTED')
                                    const StatusChip(
                                      label: 'Aceptada',
                                      color: LivoraColors.green,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Tarifas Ofrecidas por Material
                              const Text(
                                'Tarifas ofrecidas por kg:',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: LivoraColors.slate),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: bid.proposedRates.entries.map((e) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: LivoraColors.paper,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: LivoraColors.border),
                                    ),
                                    child: Text(
                                      '${materialLabel(e.key)}: S/ ${e.value.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: LivoraColors.deep,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),

                              // Caja de Ganancia Neta para el Hogar
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tu ganancia estimada (40%):',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: LivoraColors.deep,
                                          ),
                                        ),
                                        Text(
                                          'Abono directo en EcoTokens',
                                          style: TextStyle(fontSize: 10.5, color: LivoraColors.slate),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '≈ S/ ${bid.totalEstimatedEco.toStringAsFixed(2)} PEN',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: LivoraColors.forest,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Botón Aceptar Oferta
                              if (bid.status != 'ACCEPTED' && isAuctionOpen) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      minimumSize: const Size(0, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: _selectingBidId == bid.id
                                        ? null
                                        : () => _selectBid(bid),
                                    icon: _selectingBidId == bid.id
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check, size: 18),
                                    label: Text(_selectingBidId == bid.id
                                        ? 'Aceptando propuesta…'
                                        : 'Aceptar esta oferta'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                  const SizedBox(height: 16),

                  // Botón Cancelar Subasta
                  if (isAuctionOpen)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8C3A3A),
                        side: const BorderSide(color: Color(0xFF8C3A3A)),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _cancelling ? null : _cancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: Text(_cancelling ? 'Cancelando…' : 'Cancelar solicitud en subasta'),
                    ),
                ],
              ),
            ),
    );
  }
}
