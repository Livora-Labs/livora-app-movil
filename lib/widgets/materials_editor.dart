import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/formats.dart';

/// Editor de materiales y pesos (kg). Notifica el mapa {MATERIAL: kg}
/// cada vez que cambia.
class MaterialsEditor extends StatefulWidget {
  const MaterialsEditor({
    super.key,
    required this.onChanged,
    this.initial,
  });

  final ValueChanged<Map<String, double>> onChanged;
  final Map<String, double>? initial;

  @override
  State<MaterialsEditor> createState() => _MaterialsEditorState();
}

class _Entry {
  _Entry(this.material, [double? kg])
      : controller = TextEditingController(
          text: kg == null ? '' : fmtNumber(kg),
        );

  String material;
  final TextEditingController controller;

  double get kg => double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
}

class _MaterialsEditorState extends State<MaterialsEditor> {
  final List<_Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.isNotEmpty) {
      initial.forEach((material, kg) => _entries.add(_Entry(material, kg)));
    } else {
      _entries.add(_Entry(kMaterialOptions.first));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  void _notify() {
    final result = <String, double>{};
    for (final entry in _entries) {
      if (entry.kg > 0) {
        result[entry.material] = (result[entry.material] ?? 0) + entry.kg;
      }
    }
    widget.onChanged(result);
  }

  List<String> _optionsFor(_Entry entry) {
    final used = _entries.where((e) => e != entry).map((e) => e.material).toSet();
    return [
      entry.material,
      ...kMaterialOptions.where((m) => m != entry.material && !used.contains(m)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in _entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    initialValue: entry.material,
                    decoration: livoraInput('Material'),
                    items: [
                      for (final material in _optionsFor(entry))
                        DropdownMenuItem(
                          value: material,
                          child: Text(materialLabel(material)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => entry.material = value);
                      _notify();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: entry.controller,
                    decoration: livoraInput('Kg'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,]'),
                      ),
                    ],
                    onChanged: (_) => _notify(),
                  ),
                ),
                IconButton(
                  onPressed: _entries.length == 1
                      ? null
                      : () {
                          setState(() => _entries.remove(entry));
                          _notify();
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: const Color(0xFF9E4B4B),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _entries.length >= kMaterialOptions.length
                ? null
                : () {
                    final used = _entries.map((e) => e.material).toSet();
                    final next = kMaterialOptions.firstWhere(
                      (m) => !used.contains(m),
                      orElse: () => kMaterialOptions.first,
                    );
                    setState(() => _entries.add(_Entry(next)));
                  },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Agregar material'),
          ),
        ),
      ],
    );
  }
}
