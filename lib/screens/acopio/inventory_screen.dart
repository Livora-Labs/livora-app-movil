import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/paging_controller.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_empty_state.dart';
import '../../widgets/livora_shimmer.dart';
import '../../widgets/paginated_list_view.dart';
import 'sale_screen.dart';
import '../common/profile.dart';

/// Inventario de materiales reciclables: gestión de stock, Kárdex y ventas B2B para CENTRO_ACOPIO.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.canRegisterSale = false});

  /// Los centros de acopio además pueden registrar ventas B2B.
  final bool canRegisterSale;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<LivoraApi>().inventory();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  double get _totalKg =>
      (_items ?? []).fold(0, (sum, item) => sum + item.quantityKg);

  Future<void> _openMaterialKardex(InventoryItem item) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MaterialKardexBottomSheet(item: item),
    );
    if (mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      appBar: livoraAppBar(
        context,
        'Inventario',
        actions: [
          if (widget.canRegisterSale)
            IconButton(
              tooltip: 'Registrar venta B2B',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SaleScreen()),
                );
                _load();
              },
              icon: const Icon(Icons.point_of_sale_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LivoraColors.brandGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock total',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmtKg(_totalKg),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${items?.length ?? 0} tipo(s) de material',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle(text: 'Materiales en stock (Toca para ver historial de movimientos)'),
            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                title: 'No se pudo cargar el inventario',
                message: _error,
              )
            else if (items == null)
              const LivoraShimmerList(
                itemCount: 4,
                padding: EdgeInsets.zero,
              )
            else if (items.isEmpty)
              const LivoraEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Inventario vacío',
                message:
                    'Cuando recibas y proceses lotes, el stock de materiales aparecerá aquí.',
                padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
              )
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      onTap: () => _openMaterialKardex(item),
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: LivoraColors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.recycling,
                            color: LivoraColors.forest,
                          ),
                        ),
                        title: Text(
                          materialLabel(item.materialType),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: LivoraColors.deep,
                          ),
                        ),
                        subtitle: Text(
                          'Actualizado: ${fmtDate(item.updatedAt)} · Ver movimientos',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fmtKg(item.quantityKg),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.forest,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Modal inferior detallado del Kárdex de movimientos para un material específico.
class _MaterialKardexBottomSheet extends StatefulWidget {
  const _MaterialKardexBottomSheet({required this.item});

  final InventoryItem item;

  @override
  State<_MaterialKardexBottomSheet> createState() =>
      _MaterialKardexBottomSheetState();
}

class _MaterialKardexBottomSheetState
    extends State<_MaterialKardexBottomSheet> {
  late double _stock;
  late final PagingController<InventoryMovement> _pagingController;

  @override
  void initState() {
    super.initState();
    _stock = widget.item.quantityKg;
    _pagingController = PagingController<InventoryMovement>(
      fetcher: (page, limit) =>
          context.read<LivoraApi>().fetchInventoryMovements(
                materialType: widget.item.materialType,
                page: page,
                limit: limit,
              ),
      keySelector: (m) => m.id,
      pageSize: 15,
    );
    _pagingController.loadFirstPage();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchKardex() async {
    await _pagingController.refresh();
  }

  Future<void> _showRegisterMermaDialog() async {
    final weightController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool busy = false;

    final registered = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.remove_circle_outline,
            color: LivoraColors.coral,
            size: 36,
          ),
          title: const Text('Registrar Merma'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Material: ${materialLabel(widget.item.materialType)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock disponible: ${fmtKg(_stock)}',
                  style: const TextStyle(fontSize: 12, color: LivoraColors.deep),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: weightController,
                  decoration: livoraInput('Cantidad de merma (kg)', icon: Icons.scale),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: kDecimalInputFormatters,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa los kg de merma';
                    }
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) {
                      return 'Ingresa un peso mayor a 0 kg';
                    }
                    if (parsed > _stock) {
                      return 'No puede exceder el stock disponible (${fmtKg(_stock)})';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: LivoraColors.coral),
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      final kg = double.parse(
                        weightController.text.replaceAll(',', '.'),
                      );
                      try {
                        await context.read<LivoraApi>().createInventoryMovement(
                              type: 'OUT',
                              materialType: widget.item.materialType,
                              quantityKg: kg,
                            );
                        if (ctx.mounted) Navigator.pop(dialogCtx, true);
                      } on ApiException catch (e) {
                        if (ctx.mounted) {
                          showAppSnack(ctx, e.message, error: true);
                          setDialogState(() => busy = false);
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Registrar Merma'),
            ),
          ],
        ),
      ),
    );

    weightController.dispose();

    if (registered == true && mounted) {
      showAppSnack(context, 'Merma registrada con éxito.');
      setState(() {
        _stock = (_stock - (double.tryParse(weightController.text.replaceAll(',', '.')) ?? 0))
            .clamp(0, double.infinity);
      });
      _fetchKardex();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LivoraColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: LivoraColors.forest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      materialLabel(widget.item.materialType),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                    Text(
                      'Stock: ${fmtKg(_stock)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: LivoraColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LivoraColors.coral,
                  side: const BorderSide(color: LivoraColors.coral),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: _stock > 0 ? _showRegisterMermaDialog : null,
                icon: const Icon(Icons.remove_circle_outline, size: 16),
                label: const Text(
                  'Registrar Merma',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historial de Movimientos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LivoraColors.deep,
                ),
              ),
              AnimatedBuilder(
                animation: _pagingController,
                builder: (context, _) => _pagingController.isLoadingFirstPage
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Refrescar',
                        onPressed: _fetchKardex,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PaginatedListView<InventoryMovement>(
              controller: _pagingController,
              padding: const EdgeInsets.symmetric(vertical: 4),
              emptyState: const LivoraEmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Sin movimientos',
                message: 'No hay movimientos registrados para este material.',
                padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
              ),
              itemBuilder: (ctx, m, i) {
                final isInput = m.type.toUpperCase() == 'IN';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isInput
                              ? LivoraColors.forest
                              : LivoraColors.coral)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isInput
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: isInput
                          ? LivoraColors.forest
                          : LivoraColors.coral,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    isInput
                        ? 'Entrada (+${fmtKg(m.quantityKg)})'
                        : 'Salida / Merma (-${fmtKg(m.quantityKg)})',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isInput
                          ? LivoraColors.forest
                          : LivoraColors.coral,
                    ),
                  ),
                  subtitle: Text(
                    m.createdAt != null
                        ? fmtDate(m.createdAt)
                        : '—',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  trailing: Chip(
                    label: Text(
                      m.type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isInput
                            ? LivoraColors.forest
                            : LivoraColors.coral,
                      ),
                    ),
                    backgroundColor: (isInput
                            ? LivoraColors.forest
                            : LivoraColors.coral)
                        .withValues(alpha: 0.08),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide.none,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
