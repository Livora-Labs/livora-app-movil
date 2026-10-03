import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/paging_controller.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';
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
  int _selectedSegment = 0; // 0: Stock, 1: Despachos B2B
  List<B2bTransfer>? _transfers;
  bool _loadingTransfers = false;
  String? _transfersError;
  StreamSubscription<Map<String, dynamic>>? _batchCompletedSub;
  StreamSubscription<Map<String, dynamic>>? _updateSub;
  int? _lastBatchesVersion;
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final realtime = context.read<LivoraRealtime>();
      _batchCompletedSub = realtime
          .on(RealtimeEvents.batchCompleted)
          .listen((_) {
        if (mounted && !_loadInProgress) _load();
      });
      _updateSub = realtime
          .on(RealtimeEvents.collectionUpdated)
          .listen((_) {
        if (mounted && !_loadInProgress) _load();
      });
    });
  }

  @override
  void dispose() {
    _batchCompletedSub?.cancel();
    _updateSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    try {
      final items = await context.read<LivoraApi>().inventory();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
      if (widget.canRegisterSale) {
        _loadTransfers();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _loadTransfers() async {
    setState(() {
      _loadingTransfers = true;
      _transfersError = null;
    });
    try {
      final transfers = await context.read<LivoraApi>().fetchB2bTransfers();
      if (mounted) {
        setState(() {
          _transfers = transfers;
          _loadingTransfers = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _transfersError = e.message;
          _loadingTransfers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTransfers = false);
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

  Future<void> _showAcceptTransferModal(B2bTransfer transfer) async {
    final controllers = <String, TextEditingController>{};
    final matList = transfer.materials.isNotEmpty
        ? transfer.materials.keys.toList()
        : ['PET'];

    for (final mat in matList) {
      final initialKg = transfer.materials[mat] ?? 0.0;
      controllers[mat] = TextEditingController(
        text: initialKg > 0 ? fmtNumber(initialKg) : '',
      );
    }
    final notesController = TextEditingController();
    bool busy = false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.handshake_outlined, color: LivoraColors.forest),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cerrar Trato y Despachar #${transfer.shortId}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Empresa: ${transfer.buyerLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ingresa los kilogramos netos reales cargados en camión para descontar del stock físico:',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                for (final mat in matList) ...[
                  TextFormField(
                    controller: controllers[mat],
                    decoration: livoraInput(
                      'Kg reales de ${materialLabel(mat)}',
                      icon: Icons.scale_outlined,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: kDecimalInputFormatters,
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: notesController,
                  decoration: livoraInput('Notas de despacho (opcional)', icon: Icons.notes_outlined),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
              onPressed: busy
                  ? null
                  : () async {
                      final actuals = <Map<String, dynamic>>[];
                      for (final entry in controllers.entries) {
                        final val = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0.0;
                        if (val > 0) {
                          actuals.add({'material': entry.key, 'weightKg': val});
                        }
                      }
                      if (actuals.isEmpty) {
                        showAppSnack(ctx, 'Ingresa el peso real de al menos un material', error: true);
                        return;
                      }

                      setDialogState(() => busy = true);
                      try {
                        await context.read<LivoraApi>().acceptB2bTransfer(
                          id: transfer.id,
                          actualMaterials: actuals,
                          notes: notesController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(dialogCtx, true);
                      } on ApiException catch (e) {
                        if (ctx.mounted) {
                          showAppSnack(ctx, e.message, error: true);
                          setDialogState(() => busy = false);
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          showAppSnack(ctx, 'Error al despachar pedido', error: true);
                          setDialogState(() => busy = false);
                        }
                      }
                    },
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.local_shipping_outlined, size: 16),
              label: const Text('Despachar Lote'),
            ),
          ],
        ),
      ),
    );

    for (final c in controllers.values) {
      c.dispose();
    }
    notesController.dispose();

    if (accepted == true && mounted) {
      showAppSnack(context, '¡Pedido aceptado y lote despachado con éxito!');
      _load();
      _loadTransfers();
    }
  }

  Future<void> _showDispatchGuideModal(B2bTransfer transfer) async {
    final qrData = transfer.trackingCode ?? transfer.id;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: LivoraColors.forest),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Guía de Remisión #${transfer.shortId}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 190,
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
              const SizedBox(height: 12),
              Text(
                'Código de Guía para el Chofer: ${transfer.trackingCode ?? transfer.shortId}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    InfoRow(label: 'Empresa Destino', value: transfer.buyerLabel),
                    InfoRow(label: 'Carga Total', value: fmtKg(transfer.totalWeightKg)),
                    if (transfer.driverName != null)
                      InfoRow(label: 'Conductor', value: transfer.driverName!),
                    if (transfer.licensePlate != null)
                      InfoRow(label: 'Placa', value: transfer.licensePlate!),
                    if (transfer.manifestCid != null)
                      InfoRow(
                        label: 'Manifiesto IPFS',
                        value: transfer.manifestCid!.length > 12
                            ? '${transfer.manifestCid!.substring(0, 12)}...'
                            : transfer.manifestCid!,
                      ),
                    if (transfer.stellarTxHash != null)
                      InfoRow(
                        label: 'Stellar On-Chain',
                        value: transfer.stellarTxHash!.length > 12
                            ? '${transfer.stellarTxHash!.substring(0, 12)}...'
                            : transfer.stellarTxHash!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (_lastBatchesVersion != session.batchesVersion) {
      _lastBatchesVersion = session.batchesVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loadInProgress) {
          _load();
        }
      });
    }

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
        onRefresh: () async {
          await _load();
          if (widget.canRegisterSale) await _loadTransfers();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            if (widget.canRegisterSale) ...[
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(
                        child: Text('Stock de Planta', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      selected: _selectedSegment == 0,
                      selectedColor: LivoraColors.mint.withValues(alpha: 0.35),
                      onSelected: (_) => setState(() => _selectedSegment = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Despachos B2B', style: TextStyle(fontWeight: FontWeight.w700)),
                            if (_transfers != null && _transfers!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: LivoraColors.forest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_transfers!.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      selected: _selectedSegment == 1,
                      selectedColor: LivoraColors.mint.withValues(alpha: 0.35),
                      onSelected: (_) => setState(() => _selectedSegment = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_selectedSegment == 0) ...[
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
            ] else ...[
              // Segment 1: Despachos B2B / Salidas a Industria
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LivoraColors.forest.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_shipping_outlined, color: LivoraColors.forest, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Despachos B2B a Industria',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              Text(
                                'Salidas de camiones con trazabilidad y guía QR',
                                style: TextStyle(fontSize: 11.5, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: LivoraColors.forest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SaleScreen()),
                        );
                        _load();
                        _loadTransfers();
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Registrar Nueva Salida B2B'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionTitle(text: 'Historial de Camiones Despachados'),
              if (_transfersError != null)
                EmptyState(
                  icon: Icons.error_outline,
                  title: 'Error al cargar despachos',
                  message: _transfersError,
                )
              else if (_loadingTransfers)
                const LivoraShimmerList(itemCount: 3, padding: EdgeInsets.zero)
              else if (_transfers == null || _transfers!.isEmpty)
                LivoraEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'Sin despachos registrados',
                  message: 'Cuando registres una salida de camión hacia una industria compradora aparecerá aquí con su guía QR.',
                  actionLabel: 'Registrar Despacho',
                  onAction: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SaleScreen()),
                    );
                    _load();
                    _loadTransfers();
                  },
                )
              else
                for (final transfer in _transfers!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _B2bTransferCard(
                      transfer: transfer,
                      onShowGuide: () => _showDispatchGuideModal(transfer),
                      onAccept: transfer.status == 'REQUESTED'
                          ? () => _showAcceptTransferModal(transfer)
                          : null,
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _B2bTransferCard extends StatelessWidget {
  const _B2bTransferCard({
    required this.transfer,
    required this.onShowGuide,
    this.onAccept,
  });

  final B2bTransfer transfer;
  final VoidCallback onShowGuide;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (transfer.status) {
      'DELIVERED' || 'RECEIVED' => LivoraColors.green,
      'ACCEPTED' || 'DISPATCHED' => LivoraColors.blue,
      'REQUESTED' => Colors.amber.shade800,
      'REJECTED' => LivoraColors.coral,
      _ => Colors.grey.shade700,
    };
    final statusLabel = switch (transfer.status) {
      'DELIVERED' || 'RECEIVED' => 'Entregado en Planta',
      'ACCEPTED' || 'DISPATCHED' => 'En Tránsito a Planta',
      'REQUESTED' => 'Solicitud Entrante B2B',
      'REJECTED' => 'Rechazado',
      _ => transfer.status,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    transfer.buyerLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Carga: ${fmtKg(transfer.totalWeightKg)} · Despacho #${transfer.shortId}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: LivoraColors.deep),
            ),
            if (transfer.materials.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                transfer.materials.entries
                    .map((e) => '${materialLabel(e.key)}: ${fmtKg(e.value)}')
                    .join(' · '),
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (transfer.dispatchedAt != null)
                  Text(
                    'Salida: ${fmtDate(transfer.dispatchedAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                const Spacer(),
                if (transfer.status == 'REQUESTED' && onAccept != null) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: LivoraColors.forest,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: onAccept,
                    icon: const Icon(Icons.handshake_outlined, size: 14),
                    label: const Text(
                      'Cerrar Trato',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: LivoraColors.forest),
                  ),
                  onPressed: onShowGuide,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: LivoraColors.forest),
                  label: const Text(
                    'Guía Chofer QR',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: LivoraColors.forest),
                  ),
                ),
              ],
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

    final weightDelta = double.tryParse(weightController.text.replaceAll(',', '.')) ?? 0.0;
    weightController.dispose();

    if (registered == true && mounted) {
      showAppSnack(context, 'Merma registrada con éxito.');
      setState(() {
        _stock = (_stock - weightDelta).clamp(0, double.infinity);
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
