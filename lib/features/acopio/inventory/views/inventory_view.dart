import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../models/models.dart';
import '../../../../widgets/common.dart';
import '../../../../widgets/livora_empty_state.dart';
import '../../../../widgets/livora_shimmer.dart';
import '../../../../screens/acopio/sale_screen.dart';
import '../../../../screens/common/profile.dart';
import '../view_model/inventory_view_model.dart';
import '../widgets/b2b_transfer_card.dart';
import '../widgets/inventory_item_card.dart';

/// Vista limpia MVVM para Inventario y Operaciones B2B (<220 líneas).
class InventoryView extends StatelessWidget {
  final bool canRegisterSale;

  const InventoryView({super.key, this.canRegisterSale = false});

  Future<void> _showAcceptTransferModal(BuildContext context, InventoryViewModel vm, B2bTransfer transfer) async {
    final controllers = <String, TextEditingController>{};
    final matList = transfer.materials.isNotEmpty ? transfer.materials.keys.toList() : ['PET'];

    for (final mat in matList) {
      final initialKg = transfer.materials[mat] ?? 0.0;
      controllers[mat] = TextEditingController(text: initialKg > 0 ? fmtNumber(initialKg) : '');
    }
    final notesController = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirmar Recepción B2B'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Verifica los pesos netos recepcionados en balanza:'),
              const SizedBox(height: 12),
              ...matList.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: controllers[m],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: livoraInput('$m (kg)'),
                    ),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: livoraInput('Observaciones / Guía Remisión'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (accepted == true && context.mounted) {
      final weights = <String, double>{};
      for (final m in matList) {
        weights[m] = double.tryParse(controllers[m]?.text ?? '0') ?? 0.0;
      }
      try {
        await vm.acceptTransfer(transfer.id, materialsReceived: weights, notes: notesController.text);
        if (context.mounted) showAppSnack(context, 'Despacho B2B recepcionado exitosamente');
      } catch (e) {
        if (context.mounted) showAppSnack(context, 'Error al recepcionar: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();

    return Scaffold(
      appBar: livoraAppBar(
        context,
        'Inventario y Kárdex',
        actions: [
          if (canRegisterSale)
            IconButton(
              tooltip: 'Registrar Venta B2B',
              icon: const Icon(Icons.add_shopping_cart_rounded),
              onPressed: () async {
                final sold = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const SaleScreen()),
                );
                if (sold == true) {
                  vm.loadInventory(forceRefresh: true);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (canRegisterSale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Stock Actual'), icon: Icon(Icons.inventory_2_outlined)),
                  ButtonSegment(value: 1, label: Text('Despachos B2B'), icon: Icon(Icons.local_shipping_outlined)),
                ],
                selected: {vm.selectedSegment},
                onSelectionChanged: (set) => vm.setSegment(set.first),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: LivoraColors.paper,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Capacidad Total en Acopio:', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  fmtKg(vm.totalKg),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: LivoraColors.forest),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await vm.loadInventory(forceRefresh: true);
                if (canRegisterSale) await vm.loadTransfers();
              },
              child: vm.selectedSegment == 0
                  ? _buildStockList(context, vm)
                  : _buildTransfersList(context, vm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockList(BuildContext context, InventoryViewModel vm) {
    final state = vm.itemsState;

    if (state.isLoading && state.dataOrNull == null) {
      return const LivoraShimmerList(itemCount: 4);
    }

    if (state.isError && state.dataOrNull == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text(state.errorMessageOrNull ?? 'Error cargando stock'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => vm.loadInventory(forceRefresh: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final items = state.dataOrNull ?? [];
    if (items.isEmpty) {
      return const LivoraEmptyState(
        title: 'Sin materiales en inventario',
        message: 'Cuando recibas lotes confirmados, el stock se actualizará automáticamente.',
        icon: Icons.inventory_2_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: items.length,
      itemBuilder: (_, i) => InventoryItemCard(
        item: items[i],
        onTap: () {},
      ),
    );
  }

  Widget _buildTransfersList(BuildContext context, InventoryViewModel vm) {
    final state = vm.transfersState;
    if (state.isLoading && state.dataOrNull == null) {
      return const LivoraShimmerList(itemCount: 3);
    }
    final transfers = state.dataOrNull ?? [];
    if (transfers.isEmpty) {
      return const LivoraEmptyState(
        title: 'No hay despachos B2B',
        message: 'Las órdenes de transferencia hacia plantas recicladoras aparecerán aquí.',
        icon: Icons.local_shipping_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      itemCount: transfers.length,
      itemBuilder: (_, i) => B2bTransferCard(
        transfer: transfers[i],
        onAccept: () => _showAcceptTransferModal(context, vm, transfers[i]),
        onReject: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Para observar o rechazar una carga, comunícate con soporte de operaciones')),
          );
        },
      ),
    );
  }
}
