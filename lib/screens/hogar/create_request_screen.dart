import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../../widgets/materials_editor.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController(text: '4.6097');
  final _lngController = TextEditingController(text: '-74.0817');

  Map<String, double> _materials = {};
  bool _busy = false;
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    if (_fetchingLocation) return;
    setState(() => _fetchingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _latController.text = pos.latitude.toStringAsFixed(6);
          _lngController.text = pos.longitude.toStringAsFixed(6);
        });
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  double? _coord(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_materials.isEmpty) {
      showAppSnack(
        context,
        'Agrega al menos un material con su peso estimado',
        error: true,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final request = await context.read<LivoraApi>().createCollectionRequest(
            itemsEstimated: _materials,
            latitude: _coord(_latController)!,
            longitude: _coord(_lngController)!,
            description: _descriptionController.text.trim(),
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: LivoraColors.green,
            size: 40,
          ),
          title: const Text('¡Solicitud creada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cuando el recolector llegue, pídele confirmar con este PIN:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                request.verificationPin ?? '----',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: LivoraColors.forest,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva recolección')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(text: '¿Qué vas a reciclar?'),
                MaterialsEditor(
                  onChanged: (materials) => _materials = materials,
                ),
                const SizedBox(height: 8),
                const SectionTitle(text: 'Detalles'),
                TextFormField(
                  controller: _descriptionController,
                  decoration: livoraInput(
                    'Notas para el recolector (opcional)',
                    hint: 'Ej. Bolsa blanca junto a la puerta',
                    icon: Icons.sticky_note_2_outlined,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: livoraInput('Latitud'),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,\-]'),
                          ),
                        ],
                        validator: (_) {
                          final lat = _coord(_latController);
                          return lat == null || lat < -90 || lat > 90
                              ? 'Latitud inválida'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        decoration: livoraInput('Longitud'),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,\-]'),
                          ),
                        ],
                        validator: (_) {
                          final lng = _coord(_lngController);
                          return lng == null || lng < -180 || lng > 180
                              ? 'Longitud inválida'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _fetchingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: LivoraColors.forest,
                              ),
                            )
                          : const Icon(Icons.my_location, color: LivoraColors.forest),
                      onPressed: _fetchingLocation ? null : _fetchCurrentLocation,
                      tooltip: 'Obtener mi ubicación actual',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Coordenadas GPS del punto de recogida. Los recolectores '
                  'cercanos verán tu solicitud.',
                  style: TextStyle(
                    fontSize: 12,
                    color: LivoraColors.ink.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 22),
                BusyButton(
                  label: 'Crear solicitud',
                  icon: Icons.recycling,
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
