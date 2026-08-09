import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../acopio/sale_screen.dart';
import '../common/profile.dart';

/// Inventario de materiales: usado por TIENDA (ALMACEN) y CENTRO_ACOPIO.
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

  Future<void> _openMovementSheet() async {
    final registered = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _MovementSheet(),
    );
    if (registered == true) _load();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openMovementSheet,
        icon: const Icon(Icons.swap_vert),
        label: const Text('Movimiento'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
            const SectionTitle(text: 'Materiales en stock'),
            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                title: 'No se pudo cargar el inventario',
                message: _error,
              )
            else if (items == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const EmptyState(
                icon: Icons.inventory_outlined,
                title: 'Inventario vacío',
                message:
                    'Registra un movimiento de entrada (IN) para agregar stock.',
              )
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
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
                        'Actualizado: ${fmtDate(item.updatedAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        fmtKg(item.quantityKg),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.forest,
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

/// Formulario de movimiento de inventario (entrada / salida).
class _MovementSheet extends StatefulWidget {
  const _MovementSheet();

  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _customMaterialController = TextEditingController();

  String _type = 'IN';
  String _material = kMaterialOptions.first;
  bool _customMaterial = false;
  bool _busy = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _customMaterialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final material = _customMaterial
        ? _customMaterialController.text.trim().toUpperCase()
        : _material;

    setState(() => _busy = true);
    try {
      await context.read<LivoraApi>().createInventoryMovement(
            type: _type,
            materialType: material,
            quantityKg: double.parse(
              _quantityController.text.replaceAll(',', '.'),
            ),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, error.message, error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Registrar movimiento',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: LivoraColors.deep,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'IN',
                  label: Text('Entrada'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: 'OUT',
                  label: Text('Salida'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            if (!_customMaterial)
              DropdownButtonFormField<String>(
                initialValue: _material,
                decoration: livoraInput('Material'),
                items: [
                  for (final material in kMaterialOptions)
                    DropdownMenuItem(
                      value: material,
                      child: Text(materialLabel(material)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _material = value ?? _material),
              )
            else
              TextFormField(
                controller: _customMaterialController,
                decoration: livoraInput(
                  'Material personalizado',
                  hint: 'Ej. TETRA_PAK',
                ),
                validator: (value) =>
                    _customMaterial && (value == null || value.trim().isEmpty)
                        ? 'Escribe el nombre del material'
                        : null,
              ),
            TextButton(
              onPressed: () =>
                  setState(() => _customMaterial = !_customMaterial),
              child: Text(
                _customMaterial
                    ? 'Usar lista de materiales'
                    : 'Escribir otro material',
              ),
            ),
            TextFormField(
              controller: _quantityController,
              decoration: livoraInput('Cantidad (kg)', icon: Icons.scale),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              validator: (value) {
                final quantity =
                    double.tryParse((value ?? '').replaceAll(',', '.'));
                return quantity == null || quantity <= 0
                    ? 'Ingresa una cantidad válida'
                    : null;
              },
            ),
            const SizedBox(height: 18),
            BusyButton(
              label: _type == 'IN' ? 'Registrar entrada' : 'Registrar salida',
              icon: Icons.save_outlined,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
