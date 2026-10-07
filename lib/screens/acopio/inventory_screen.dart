import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../features/acopio/inventory/view_model/inventory_view_model.dart';
import '../../features/acopio/inventory/views/inventory_view.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';

/// Pantalla de inventario y kárdex delegada al patrón MVVM Clean Architecture.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key, this.canRegisterSale = false});

  final bool canRegisterSale;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final centerId = user?.id ?? '';

    return ChangeNotifierProvider(
      create: (ctx) => InventoryViewModel(
        repository: InventoryRepository(ctx.read<LivoraApi>()),
        centerId: centerId,
        realtime: ctx.read<LivoraRealtime>(),
        canRegisterSale: canRegisterSale,
      ),
      child: InventoryView(canRegisterSale: canRegisterSale),
    );
  }
}
