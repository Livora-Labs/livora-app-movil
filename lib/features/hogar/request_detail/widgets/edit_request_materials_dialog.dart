import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/formats.dart';
import '../../../../models/models.dart';
import '../../../../screens/hogar/widgets/material_slider_card.dart';
import '../view_model/request_detail_view_model.dart';

/// Diálogo para editar materiales o notas de una solicitud en estado PENDING o AUCTION_OPEN.
class EditRequestMaterialsDialog extends StatefulWidget {
  const EditRequestMaterialsDialog({
    super.key,
    required this.request,
    required this.viewModel,
  });

  final CollectionRequest request;
  final RequestDetailViewModel viewModel;

  static Future<void> show(BuildContext context, {
    required CollectionRequest request,
    required RequestDetailViewModel viewModel,
  }) {
    return showDialog(
      context: context,
      builder: (_) => EditRequestMaterialsDialog(
        request: request,
        viewModel: viewModel,
      ),
    );
  }

  @override
  State<EditRequestMaterialsDialog> createState() => _EditRequestMaterialsDialogState();
}

class _EditRequestMaterialsDialogState extends State<EditRequestMaterialsDialog> {
  final Map<String, TextEditingController> _controllers = {};
  late final TextEditingController _descCtrl;
  bool _saving = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    widget.request.itemsEstimated.forEach((mat, wt) {
      _controllers[mat] = TextEditingController(text: wt.toStringAsFixed(1));
    });
    _descCtrl = TextEditingController(text: widget.request.description ?? '');
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unusedOptions = kMaterialOptions.where((opt) =>
        !_controllers.keys.any((k) => k.toUpperCase() == opt.toUpperCase())).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.edit_note_rounded, color: LivoraColors.forest),
          SizedBox(width: 8),
          Text('Editar Solicitud', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modifica los materiales o cantidades estimadas:',
                style: TextStyle(fontSize: 13, color: LivoraColors.slate),
              ),
              const SizedBox(height: 12),
              if (_controllers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No hay materiales agregados. Añade al menos uno abajo.',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ),
              ..._controllers.entries.map(
                (entry) {
                  final spec = kMaterialSpecs[entry.key.toUpperCase()];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          spec?.icon ?? Icons.recycling_rounded,
                          size: 18,
                          color: spec?.color ?? LivoraColors.forest,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: Text(
                            materialLabel(entry.key),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: entry.value,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: kDecimalInputFormatters,
                            onChanged: (_) {
                              if (_localError != null) setState(() => _localError = null);
                            },
                            decoration: const InputDecoration(
                              suffixText: 'kg',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        if (_controllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.black45),
                            padding: const EdgeInsets.only(left: 4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Eliminar material',
                            onPressed: () {
                              setState(() {
                                _controllers.remove(entry.key)?.dispose();
                                if (_localError != null) _localError = null;
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
              if (unusedOptions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final opt in unusedOptions)
                      ActionChip(
                        label: Text('+ ${materialLabel(opt)}', style: const TextStyle(fontSize: 11)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () {
                          setState(() {
                            _controllers[opt] = TextEditingController(text: '1.0');
                            if (_localError != null) _localError = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Notas o indicaciones:',
                style: TextStyle(fontSize: 13, color: LivoraColors.slate),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Indicaciones actualizadas para el recolector...',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              if (_localError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _localError!,
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LivoraColors.forest,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar cambios'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final updatedItems = <String, double>{};
    double totalKg = 0;
    _controllers.forEach((k, v) {
      final parsed = double.tryParse(v.text.replaceAll(',', '.')) ?? 0;
      if (parsed > 0) {
        updatedItems[k] = parsed;
        totalKg += parsed;
      }
    });

    if (updatedItems.isEmpty) {
      setState(() => _localError = 'Ingresa al menos un material con peso mayor a 0 kg.');
      return;
    }
    if (totalKg < 0.5) {
      setState(() => _localError = 'El peso total estimado debe ser al menos 0.5 kg.');
      return;
    }

    setState(() {
      _saving = true;
      _localError = null;
    });

    try {
      await widget.viewModel.editRequest(
        itemsEstimated: updatedItems,
        description: _descCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _localError = 'Error al actualizar: $e';
        });
      }
    }
  }
}
