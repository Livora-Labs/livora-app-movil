import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/batch_repository.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/livora_api.dart';
import '../../../../services/livora_realtime.dart';
import '../../../../widgets/batch_detail_modal.dart';
import '../../../../widgets/livora_empty_state.dart';
import '../../../../widgets/view_state_scaffold.dart';
import '../view_model/center_batches_view_model.dart';
import '../widgets/batch_card_item.dart';
import '../widgets/batch_filter_chips.dart';

/// Vista desacoplada para la administración de lotes en Centro de Acopio (<220 líneas).
class CenterBatchesView extends StatelessWidget {
  const CenterBatchesView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CenterBatchesViewModel(
        repository: BatchRepository(api: ctx.read<LivoraApi>()),
        realtime: ctx.read<LivoraRealtime>(),
        api: ctx.read<LivoraApi>(),
      ),
      child: const _CenterBatchesContent(),
    );
  }
}

class _CenterBatchesContent extends StatelessWidget {
  const _CenterBatchesContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CenterBatchesViewModel>();
    final state = vm.state;
    final batches = vm.filteredBatches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes del Centro'),
        actions: [
          if (vm.selectedBatchIds.isNotEmpty)
            TextButton.icon(
              icon: vm.isConsolidating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.archive_rounded, color: Colors.white, size: 18),
              label: Text(
                'Consolidar (${vm.selectedBatchIds.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              onPressed: vm.isConsolidating ? null : () => vm.consolidateSelected(),
            ),
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => vm.loadBatches(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Filtros horizontales
          BatchFilterChips(
            selectedFilter: vm.selectedFilter,
            onFilterSelected: (f) => vm.setFilter(f),
          ),

          // 2. Lista de lotes con ViewStateScaffold
          Expanded(
            child: ViewStateScaffold(
              isLoading: state.isLoading && batches.isEmpty,
              hasError: state.isError && batches.isEmpty,
              errorMessage: state is UIError<List<Batch>> ? state.message : null,
              onRetry: () => vm.loadBatches(forceRefresh: true),
              onRefresh: () => vm.loadBatches(forceRefresh: true),
              child: batches.isEmpty
                  ? const LivoraEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Sin lotes disponibles',
                      message: 'No hay lotes con el filtro de estado seleccionado.',
                    )
                  : RefreshIndicator(
                      onRefresh: () => vm.loadBatches(forceRefresh: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 160),
                        itemCount: batches.length,
                        itemBuilder: (ctx, index) {
                          final batch = batches[index];
                          final isSelected = vm.selectedBatchIds.contains(batch.id);

                          return BatchCardItem(
                            batch: batch,
                            isSelected: isSelected,
                            onTap: () {
                              if (vm.selectedBatchIds.isNotEmpty) {
                                vm.toggleSelection(batch.id);
                              } else {
                                BatchDetailModal.show(context, batch: batch);
                              }
                            },
                            onLongPress: () => vm.toggleSelection(batch.id),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
