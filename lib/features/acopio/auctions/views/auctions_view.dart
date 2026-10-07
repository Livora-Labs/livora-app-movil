import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../models/models.dart';
import '../../../../widgets/livora_empty_state.dart';
import '../../../../widgets/livora_shimmer.dart';
import '../../../../screens/common/profile.dart';
import '../view_model/auctions_view_model.dart';
import '../widgets/auction_card_item.dart';

/// Vista limpia MVVM para Subastas y Licitaciones de Centros de Acopio (<220 líneas).
class AuctionsView extends StatefulWidget {
  const AuctionsView({super.key});

  @override
  State<AuctionsView> createState() => _AuctionsViewState();
}

class _AuctionsViewState extends State<AuctionsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showBidModal(BuildContext context, AuctionsViewModel vm, CollectionRequest req) async {
    final messenger = ScaffoldMessenger.of(context);
    final controllers = <String, TextEditingController>{};
    for (final mat in req.itemsEstimated.keys) {
      final defaultPrice = vm.centerPriceMap[mat] ?? 1.0;
      controllers[mat] = TextEditingController(text: defaultPrice.toStringAsFixed(2));
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Ofertar Subasta #${req.shortId}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ingresa el precio por kilogramo (S/ PEN):', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              ...req.itemsEstimated.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: controllers[e.key],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: livoraInput('${e.key} (S/ por kg)', hint: '1.50'),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Enviar Puja'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prices = <String, double>{};
      for (final mat in req.itemsEstimated.keys) {
        prices[mat] = double.tryParse(controllers[mat]?.text ?? '1.0') ?? 1.0;
      }
      try {
        await vm.placeBid(req.id, pricePerKg: prices);
        messenger.showSnackBar(
          const SnackBar(content: Text('Oferta enviada satisfactoriamente')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error enviando oferta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuctionsViewModel>();

    return Scaffold(
      appBar: livoraAppBar(
        context,
        'Subastas y Asignaciones',
        bottom: TabBar(
          controller: _tabController,
          labelColor: LivoraColors.forest,
          unselectedLabelColor: LivoraColors.slate,
          indicatorColor: LivoraColors.forest,
          tabs: const [
            Tab(text: 'Subastas Abiertas', icon: Icon(Icons.gavel_rounded)),
            Tab(text: 'Asignadas Directas', icon: Icon(Icons.assignment_turned_in_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: vm.loadAllRequests,
            child: _buildList(
              context,
              vm,
              vm.auctionRequestsState,
              isAuction: true,
            ),
          ),
          RefreshIndicator(
            onRefresh: vm.loadAllRequests,
            child: _buildList(
              context,
              vm,
              vm.directRequestsState,
              isAuction: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AuctionsViewModel vm,
    dynamic state, {
    required bool isAuction,
  }) {
    if (state.isLoading && state.dataOrNull == null) {
      return const LivoraShimmerList(itemCount: 4);
    }

    final requests = (state.dataOrNull as List<CollectionRequest>?) ?? [];
    if (requests.isEmpty) {
      return LivoraEmptyState(
        title: isAuction ? 'Sin subastas activas' : 'Sin asignaciones directas',
        message: isAuction
            ? 'Las solicitudes vecinales en subasta competitiva se mostrarán aquí.'
            : 'Los hogares que te asignaron directamente como centro preferido aparecerán aquí.',
        icon: isAuction ? Icons.gavel_outlined : Icons.assignment_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: requests.length,
      itemBuilder: (_, i) => AuctionCardItem(
        request: requests[i],
        isClaiming: vm.claimingId == requests[i].id,
        onBid: () => _showBidModal(context, vm, requests[i]),
      ),
    );
  }
}
