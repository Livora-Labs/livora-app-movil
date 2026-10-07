import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../models/models.dart';
import '../../../../screens/hogar/auction_bids_screen.dart';

/// Sección de Subasta y Ofertas de Centros de Acopio en el Detalle de Solicitud.
class RequestAuctionBidsSection extends StatelessWidget {
  const RequestAuctionBidsSection({
    super.key,
    required this.request,
    required this.selectingBidId,
    required this.onSelectBid,
    required this.onRefresh,
  });

  final CollectionRequest request;
  final String? selectingBidId;
  final ValueChanged<String> onSelectBid;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final bids = request.bids;
    final isPendingOrAuction = request.status == 'PENDING' ||
        request.status == 'AUCTION_OPEN' ||
        request.status == 'AUCTION_ACTIVE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ofertas de Acopio (${bids.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuctionBidsScreen(request: request),
                  ),
                );
                if (updated == true) onRefresh();
              },
              icon: const Icon(Icons.fullscreen, size: 16),
              label: const Text('Ver todas', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (bids.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_empty_rounded, color: Colors.indigo, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Esperando ofertas de centros de acopio cercanos en tiempo real...',
                    style: TextStyle(fontSize: 13, color: Colors.indigo, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else
          for (final bid in bids)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: bid.status == 'ACCEPTED' ? LivoraColors.green : Colors.grey.shade300,
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
                          radius: 15,
                          backgroundColor: LivoraColors.paper,
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 16,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sanitizedPersonName(
                              bid.centerName,
                              bid.centerEmail,
                              defaultLabel: 'Centro de Acopio',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: LivoraColors.deep,
                            ),
                          ),
                        ),
                        if (bid.status == 'ACCEPTED')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: LivoraColors.mint.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Aceptada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.forest,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tarifas por kg: ${bid.proposedRates.entries.map((e) => '${materialLabel(e.key)}: S/ ${e.value.toStringAsFixed(2)}').join(' • ')}',
                      style: const TextStyle(fontSize: 12, color: LivoraColors.slate),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: LivoraColors.mint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tu recompensa estimada:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LivoraColors.deep),
                          ),
                          Text(
                            '${bid.totalEstimatedEco.toStringAsFixed(2)} LIVO',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (bid.status != 'ACCEPTED' && isPendingOrAuction) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: selectingBidId != null ? null : () => onSelectBid(bid.id),
                          icon: selectingBidId == bid.id
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: Text(
                            selectingBidId == bid.id ? 'Aceptando oferta...' : 'Aceptar oferta de este acopio',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
