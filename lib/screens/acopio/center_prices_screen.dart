import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../common/profile.dart';

class _MaterialDefault {
  const _MaterialDefault(this.code, this.name, this.defaultPrice);
  final String code;
  final String name;
  final double defaultPrice;
}

const _kDefaultMaterials = [
  _MaterialDefault('PET', 'Plástico PET (Botellas)', 1.00),
  _MaterialDefault('CARTON', 'Cartón y Papel Kraft', 0.50),
  _MaterialDefault('VIDRIO', 'Vidrio (Botellas y Frascos)', 0.30),
  _MaterialDefault('PLASTICO', 'Plástico Rígido (HDPE/PP)', 1.00),
  _MaterialDefault('ALUMINIO', 'Aluminio y Metales', 1.50),
  _MaterialDefault('TETRAPAK', 'Tetra Pak', 0.40),
  _MaterialDefault('PAPEL', 'Papel Mixto y Periódico', 0.50),
];

/// Pantalla de configuración del tarifario de compra por kg para CENTRO_ACOPIO.
class CenterPricesScreen extends StatefulWidget {
  const CenterPricesScreen({super.key});

  @override
  State<CenterPricesScreen> createState() => _CenterPricesScreenState();
}

class _CenterPricesScreenState extends State<CenterPricesScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _enabledMaterials = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final mat in _kDefaultMaterials) {
      _controllers[mat.code] = TextEditingController(
        text: mat.defaultPrice.toStringAsFixed(2),
      );
      _enabledMaterials.add(mat.code);
    }
    _loadPrices();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPrices() async {
    final session = context.read<SessionController>();
    final centerId = session.user?.id;
    if (centerId == null || centerId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sesión no válida';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prices = await context.read<LivoraApi>().fetchCenterPrices(centerId);
      if (mounted) {
        if (prices.isNotEmpty) {
          _enabledMaterials.clear();
          for (final p in prices) {
            final code = p.materialType.toUpperCase().trim();
            _enabledMaterials.add(code);
            if (_controllers.containsKey(code)) {
              _controllers[code]!.text = p.pricePerKg.toStringAsFixed(2);
            } else {
              _controllers[code] = TextEditingController(
                text: p.pricePerKg.toStringAsFixed(2),
              );
            }
          }
        }
        setState(() => _loading = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _savePrices() async {
    final payload = <Map<String, dynamic>>[];
    for (final entry in _controllers.entries) {
      if (!_enabledMaterials.contains(entry.key)) continue;
      final parsed = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0.0;
      if (parsed < 0.05) {
        showAppSnack(
          context,
          'El precio para ${entry.key} debe ser de al menos S/ 0.05 PEN/kg',
          error: true,
        );
        return;
      }
      payload.add({
        'materialType': entry.key,
        'pricePerKg': double.parse(parsed.toStringAsFixed(2)),
      });
    }

    if (payload.isEmpty) {
      showAppSnack(
        context,
        'Debes tener al menos un material activo en el tarifario',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<LivoraApi>().updateMyPrices(payload);
      await HapticFeedback.lightImpact();
      if (mounted) {
        context.read<SessionController>().notifyBatchesChanged();
        showAppSnack(
          context,
          'Tarifario actualizado exitosamente (${payload.length} materiales activos).',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: livoraAppBar(
        context,
        'Tarifario de Compra',
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _loading ? null : _loadPrices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: BusyButton(
            label: 'Guardar Tarifario',
            icon: Icons.save_outlined,
            busy: _saving,
            onPressed: _loading ? null : _savePrices,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPrices,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: LivoraColors.paper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: LivoraColors.forest.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: LivoraColors.forest.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.monetization_on_outlined,
                            color: LivoraColors.forest,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tarifas Base por Kilogramo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: LivoraColors.deep,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Precios de compra en Soles (PEN) por kg. Se utilizan para calcular el split: Hogar (40%), Recolector (50%) y Livora (10%).',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EmptyState(
                        icon: Icons.error_outline,
                        title: 'Error al cargar tarifario',
                        message: _error,
                      ),
                    ),
                  for (final mat in _kDefaultMaterials) ...[
                    _MaterialPriceCard(
                      material: mat,
                      controller: _controllers[mat.code]!,
                      isEnabled: _enabledMaterials.contains(mat.code),
                      onToggleEnabled: (val) {
                        setState(() {
                          if (val) {
                            _enabledMaterials.add(mat.code);
                          } else {
                            _enabledMaterials.remove(mat.code);
                          }
                        });
                      },
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MaterialPriceCard extends StatelessWidget {
  const _MaterialPriceCard({
    required this.material,
    required this.controller,
    required this.isEnabled,
    required this.onToggleEnabled,
    required this.onChanged,
  });

  final _MaterialDefault material;
  final TextEditingController controller;
  final bool isEnabled;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onChanged;

  void _adjust(double delta) {
    final current = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
    final updated = (current + delta).clamp(0.05, 99.99);
    controller.text = updated.toStringAsFixed(2);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
    final hogarShare = (price * 0.40).toStringAsFixed(2);
    final collectorShare = (price * 0.50).toStringAsFixed(2);
    final livoraShare = (price * 0.10).toStringAsFixed(2);
    final isValid = !isEnabled || price >= 0.05;

    return Card(
      elevation: 0,
      color: isEnabled ? null : LivoraColors.paper.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: !isEnabled
              ? Colors.grey.withValues(alpha: 0.3)
              : isValid
                  ? Colors.grey.withValues(alpha: 0.2)
                  : LivoraColors.coral.withValues(alpha: 0.6),
        ),
      ),
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
                    color: isEnabled
                        ? LivoraColors.mint.withValues(alpha: 0.25)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    material.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isEnabled ? LivoraColors.forest : Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    material.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isEnabled ? LivoraColors.deep : Colors.grey[600],
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: isEnabled,
                  activeColor: LivoraColors.forest,
                  onChanged: onToggleEnabled,
                ),
              ],
            ),
            if (!isEnabled) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_circle_outline, size: 13, color: Colors.amber.shade900),
                    const SizedBox(width: 5),
                    Text(
                      'En pausa · No se recibe actualmente en planta',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Opacity(
              opacity: isEnabled ? 1.0 : 0.45,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: controller,
                      enabled: isEnabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      onChanged: (_) => onChanged(),
                      decoration: InputDecoration(
                        prefixText: 'S/ ',
                        labelText: 'Precio compra / kg',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        errorText: isValid ? null : 'Mín. S/ 0.05',
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isEnabled) ...[
                    IconButton.outlined(
                      visualDensity: VisualDensity.compact,
                      tooltip: '- S/ 0.10',
                      icon: const Icon(Icons.remove, size: 16),
                      onPressed: () => _adjust(-0.10),
                    ),
                    IconButton.outlined(
                      visualDensity: VisualDensity.compact,
                      tooltip: '+ S/ 0.10',
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => _adjust(0.10),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: LivoraColors.paper,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Equiv. LIVO',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            '${price.toStringAsFixed(2)} LIVO',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: isEnabled ? 1.0 : 0.45,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: LivoraColors.paper.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SplitColumn(label: 'Hogar (40%)', value: 'S/ $hogarShare', color: LivoraColors.forest),
                    _SplitColumn(label: 'Recolector (50%)', value: 'S/ $collectorShare', color: LivoraColors.blue),
                    _SplitColumn(label: 'Livora (10%)', value: 'S/ $livoraShare', color: Colors.grey[700]!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitColumn extends StatelessWidget {
  const _SplitColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
