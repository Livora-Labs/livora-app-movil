import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_shimmer.dart';

/// Registro de venta B2B de material reciclable a una empresa compradora.
class SaleScreen extends StatefulWidget {
  const SaleScreen({
    super.key,
    this.initialWeightKg,
    this.initialMaterialType,
    this.consolidatedBatchId,
  });

  final double? initialWeightKg;
  final String? initialMaterialType;
  final String? consolidatedBatchId;

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  final _amountController = TextEditingController();

  String? _selectedMaterial;
  String? _selectedCompanyId;

  List<InventoryItem>? _inventory;
  List<B2bCompany>? _companies;
  bool _loadingData = true;
  String? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedMaterial = widget.initialMaterialType;
    _weightController = TextEditingController(
      text: widget.initialWeightKg == null
          ? ''
          : fmtNumber(widget.initialWeightKg!),
    );
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    setState(() {
      _loadingData = true;
      _loadError = null;
    });
    final api = context.read<LivoraApi>();
    try {
      final results = await Future.wait([
        api.inventory(),
        api.fetchB2bCompanies(),
      ]);

      if (mounted) {
        final inv = results[0] as List<InventoryItem>;
        final comps = results[1] as List<B2bCompany>;
        setState(() {
          _inventory = inv;
          _companies = comps;
          _loadingData = false;

          // Si el material inicial no está fijado, seleccionar el primero con stock
          if (_selectedMaterial == null && inv.isNotEmpty) {
            final withStock = inv.where((i) => i.quantityKg > 0).toList();
            if (withStock.isNotEmpty) {
              _selectedMaterial = withStock.first.materialType;
            } else {
              _selectedMaterial = inv.first.materialType;
            }
          }

          // Si solo hay una empresa, preseleccionarla
          if (comps.length == 1) {
            _selectedCompanyId = comps.first.id;
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.message;
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Error al cargar datos requeridos para la venta';
          _loadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double? _num(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.'));

  double get _availableStock {
    if (_selectedMaterial == null || _inventory == null) return 0.0;
    final found = _inventory!.where((i) => i.materialType == _selectedMaterial).toList();
    if (found.isEmpty) return 0.0;
    return found.first.quantityKg;
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterial == null) {
      showAppSnack(context, 'Selecciona el tipo de material', error: true);
      return;
    }
    if (_selectedCompanyId == null) {
      showAppSnack(context, 'Selecciona una empresa B2B compradora', error: true);
      return;
    }

    final weight = _num(_weightController)!;
    if (weight > _availableStock && _availableStock > 0) {
      showAppSnack(
        context,
        'El peso excede el stock disponible (${fmtKg(_availableStock)})',
        error: true,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<LivoraApi>().createSale(
            materialType: _selectedMaterial!,
            weightKg: weight,
            totalAmount: _num(_amountController)!,
            buyerId: _selectedCompanyId!,
            consolidatedBatchId: widget.consolidatedBatchId,
          );
      if (!mounted) return;
      showAppSnack(context, 'Venta B2B registrada exitosamente');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Venta B2B'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar opciones',
            onPressed: _loadDependencies,
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingData
            ? const LivoraShimmerList(
                itemCount: 4,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
              )
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: LivoraColors.coral,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadDependencies,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Selector de Material
                          DropdownButtonFormField<String>(
                            value: _selectedMaterial,
                            isExpanded: true,
                            decoration: livoraInput(
                              'Tipo de material',
                              icon: Icons.recycling,
                            ),
                            items: [
                              if (_inventory != null && _inventory!.isNotEmpty)
                                for (final item in _inventory!)
                                  DropdownMenuItem(
                                    value: item.materialType,
                                    child: Text(
                                      '${materialLabel(item.materialType)} (Stock: ${fmtKg(item.quantityKg)})',
                                    ),
                                  )
                              else
                                for (final mat in kMaterialOptions)
                                  DropdownMenuItem(
                                    value: mat,
                                    child: Text(materialLabel(mat)),
                                  ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedMaterial = val);
                              _formKey.currentState?.validate();
                            },
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Selecciona el tipo de material'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // 2. Peso a vender con validación contra stock
                          TextFormField(
                            controller: _weightController,
                            decoration: livoraInput(
                              'Peso vendido (kg)',
                              icon: Icons.scale_outlined,
                              helper: _selectedMaterial != null
                                  ? 'Stock disponible: ${fmtKg(_availableStock)}'
                                  : null,
                            ),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: kDecimalInputFormatters,
                            validator: (v) {
                              final basicErr =
                                  validateWeightKg(v, min: 0.1);
                              if (basicErr != null) return basicErr;
                              final parsed = _num(_weightController);
                              if (parsed != null &&
                                  _availableStock > 0 &&
                                  parsed > _availableStock) {
                                return 'Excede el stock disponible (${fmtKg(_availableStock)})';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // 3. Monto total en USD / Soles / Token
                          TextFormField(
                            controller: _amountController,
                            decoration: livoraInput(
                              'Monto total de la transacción (S/ / USD)',
                              icon: Icons.payments_outlined,
                            ),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: kDecimalInputFormatters,
                            validator: (v) => validateAmount(
                              v,
                              min: 0.10,
                              unit: 'Soles / USD',
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Selector de Empresa B2B verificada
                          DropdownButtonFormField<String>(
                            value: _selectedCompanyId,
                            isExpanded: true,
                            decoration: livoraInput(
                              'Empresa B2B compradora',
                              icon: Icons.business_outlined,
                              helper: (_companies != null &&
                                      _companies!.isNotEmpty)
                                  ? '${_companies!.length} empresa(s) B2B verificada(s)'
                                  : 'No hay empresas registradas',
                            ),
                            hint: const Text('Selecciona una empresa compradora'),
                            items: [
                              for (final comp in (_companies ?? <B2bCompany>[]))
                                DropdownMenuItem(
                                  value: comp.id,
                                  child: Text(
                                    '${comp.displayName} (${comp.email})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedCompanyId = val),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Selecciona una empresa B2B compradora'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: LivoraColors.paper,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: LivoraColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_outlined,
                                  size: 20,
                                  color: LivoraColors.forest,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Al registrar la venta, la empresa B2B recibirá su certificado ESG de trazabilidad inmutable.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: LivoraColors.ink
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          BusyButton(
                            label: 'Registrar venta B2B',
                            icon: Icons.point_of_sale,
                            busy: _busy,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
