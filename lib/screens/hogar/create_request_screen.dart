import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/livora_api.dart';
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

  /// Foto opcional del material. Se sube apenas se elige (a `/uploads` con
  /// `purpose: collection`) para que el error, si lo hay, salga antes de
  /// enviar el formulario y no al final.
  File? _photo;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // El backend acepta hasta 10 MB; reducimos en origen para no gastar
      // datos móviles del usuario en una foto de 12 MP.
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _photo = File(picked.path);
      _photoUrl = null;
      _uploadingPhoto = true;
    });
    try {
      final url = await context.read<LivoraApi>().uploadFile(
            filePath: picked.path,
            purpose: 'collection',
          );
      if (mounted) setState(() => _photoUrl = url);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _photo = null);
        showAppSnack(context, error.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
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
            photoUrl: _photoUrl,
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
                const SectionTitle(text: 'Foto (opcional)'),
                _PhotoField(
                  photo: _photo,
                  uploading: _uploadingPhoto,
                  uploaded: _photoUrl != null,
                  onPick: _choosePhotoSource,
                  onRemove: () => setState(() {
                    _photo = null;
                    _photoUrl = null;
                  }),
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

/// Selector de foto con vista previa y estado de subida.
class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.photo,
    required this.uploading,
    required this.uploaded,
    required this.onPick,
    required this.onRemove,
  });

  final File? photo;
  final bool uploading;
  final bool uploaded;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Añadir foto del material'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Image.file(
                photo!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              if (uploading)
                Container(
                  height: 160,
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
          ListTile(
            dense: true,
            leading: Icon(
              uploaded ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
              color: uploaded ? LivoraColors.green : LivoraColors.ink,
              size: 20,
            ),
            title: Text(
              uploading
                  ? 'Subiendo foto…'
                  : uploaded
                      ? 'Foto lista'
                      : 'Foto sin subir',
              style: const TextStyle(fontSize: 13),
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Cambiar',
                  onPressed: uploading ? null : onPick,
                  icon: const Icon(Icons.swap_horiz, size: 20),
                ),
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: uploading ? null : onRemove,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
