import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../../widgets/materials_editor.dart';
import '../../widgets/livora_map_tile_layer.dart';
import '../../widgets/center_picker_pin.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _referenceController = TextEditingController();
  final MapController _mapController = MapController();

  double _latitude = -12.0864; // Default Miraflores, Lima
  double _longitude = -77.0351;
  bool _isMapDragging = false;
  bool _geocodingAddress = false;

  Map<String, double> _materials = {};
  String _assignmentMode = 'AUTOMATIC';
  bool _busy = false;
  bool _fetchingLocation = false;

  File? _photo;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  double get _totalKg => _materials.values.fold<double>(0.0, (s, w) => s + w);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<SessionController>();
      if (session.hasActiveRequest) {
        showAppSnack(
          context,
          'Ya tienes una solicitud en curso. Complétala o cancélala antes de solicitar otra.',
          error: true,
        );
        Navigator.pop(context);
      }
    });
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _referenceController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    setState(() => _geocodingAddress = true);
    try {
      final street = await LocationService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          if (street != null && street.isNotEmpty) {
            _addressController.text = street;
          } else if (_addressController.text.trim().isEmpty) {
            _addressController.text = 'Ubicación GPS fijada';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _geocodingAddress = false);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    if (_fetchingLocation) return;
    setState(() => _fetchingLocation = true);
    try {
      final user = context.read<SessionController>().user;
      if (user?.address != null && user!.address!.isNotEmpty) {
        _addressController.text = user.address!;
      }

      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
        await _resolveAddress(pos.latitude, pos.longitude);
      } else if (mounted) {
        if (user?.latitude != null && user?.longitude != null) {
          setState(() {
            _latitude = user!.latitude!;
            _longitude = user.longitude!;
          });
          _mapController.move(LatLng(_latitude, _longitude), 15);
          if (_addressController.text.trim().isEmpty) {
            await _resolveAddress(_latitude, _longitude);
          }
        }
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
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
    } on PlatformException catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo acceder a la ${source == ImageSource.camera ? "cámara" : "galería"}. Revisa los permisos.',
          error: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al seleccionar la foto', error: true);
      }
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

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;

    final totalKg = _totalKg;
    if (totalKg < 0.5) {
      showAppSnack(
        context,
        'El peso total mínimo para crear la solicitud es de 0.5 kg.',
        error: true,
      );
      return;
    }

    final fullAddress = _referenceController.text.trim().isNotEmpty
        ? '${_addressController.text.trim()} (${_referenceController.text.trim()})'
        : _addressController.text.trim();

    final userDescription = _descriptionController.text.trim();
    final combinedNotes = [
      if (fullAddress.isNotEmpty) 'Dirección: $fullAddress',
      if (userDescription.isNotEmpty) userDescription,
    ].join(' · ');

    setState(() => _busy = true);
    try {
      final request = await context.read<LivoraApi>().createCollectionRequest(
            itemsEstimated: _materials,
            latitude: _latitude,
            longitude: _longitude,
            assignmentMode: _assignmentMode,
            description: combinedNotes.isNotEmpty ? combinedNotes : null,
            photoUrl: _photoUrl,
          );
      if (!mounted) return;
      context.read<SessionController>().updateActiveRequest(request);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: LivoraColors.green,
            size: 44,
          ),
          title: const Text('¡Solicitud creada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _assignmentMode == 'AUCTION'
                    ? 'Tu orden fue publicada en la subasta. Los centros de acopio postularán con sus mejores tarifas.'
                    : 'Un recolector o centro de acopio aceptará tu solicitud en breve.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Te notificaremos en cada paso del proceso.',
                style: TextStyle(
                  fontSize: 12,
                  color: LivoraColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(text: '¿Qué vas a reciclar?'),
                MaterialsEditor(
                  onChanged: (materials) =>
                      setState(() => _materials = materials),
                ),
                const SizedBox(height: 14),

                const SectionTitle(text: 'Foto del material (opcional)'),
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
                const SizedBox(height: 14),

                const SectionTitle(text: 'Modalidad de asignación'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'AUTOMATIC',
                      label: Text('Directa'),
                      icon: Icon(Icons.flash_on, size: 16),
                    ),
                    ButtonSegment(
                      value: 'AUCTION',
                      label: Text('Subasta'),
                      icon: Icon(Icons.gavel, size: 16),
                    ),
                  ],
                  selected: {_assignmentMode},
                  onSelectionChanged: (newVal) =>
                      setState(() => _assignmentMode = newVal.first),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: Text(
                    _assignmentMode == 'AUTOMATIC'
                        ? 'El primer centro de acopio que solicite la orden la tomará directamente.'
                        : 'Recibe propuestas de tarifas de centros de acopio y elige la ganancia en PEN más conveniente.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: LivoraColors.slate,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                const SectionTitle(text: 'Ubicación de recojo'),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: LivoraColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mini-mapa interactivo con pin central animado
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 190,
                            child: Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: LatLng(_latitude, _longitude),
                                    initialZoom: 15,
                                    maxZoom: 18,
                                    minZoom: 10,
                                    onPositionChanged: (camera, hasGesture) {
                                      if (hasGesture && !_isMapDragging) {
                                        setState(() => _isMapDragging = true);
                                      }
                                    },
                                    onMapEvent: (event) {
                                      if (event is MapEventMoveEnd) {
                                        if (_isMapDragging) {
                                          setState(() => _isMapDragging = false);
                                          HapticFeedback.lightImpact();
                                          final center = _mapController.camera.center;
                                          _latitude = center.latitude;
                                          _longitude = center.longitude;
                                          _resolveAddress(_latitude, _longitude);
                                        }
                                      }
                                    },
                                  ),
                                  children: const [
                                    LivoraMapTileLayer(),
                                  ],
                                ),

                                // Pin central interactivo
                                CenterPickerPin(isDragging: _isMapDragging),

                                // Botón flotante para recalibrar GPS nativo
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: FloatingActionButton.small(
                                    heroTag: 'recenter_hogar_create_fab',
                                    backgroundColor: Colors.white,
                                    foregroundColor: LivoraColors.forest,
                                    elevation: 2,
                                    onPressed: _fetchingLocation ? null : _fetchCurrentLocation,
                                    child: _fetchingLocation
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: LivoraColors.forest,
                                            ),
                                          )
                                        : const Icon(Icons.my_location_rounded, size: 18),
                                  ),
                                ),

                                // Atribución OpenStreetMap
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: OsmAttributionWidget(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Campo 1: Dirección detectada por mapa (editable)
                        TextFormField(
                          controller: _addressController,
                          decoration: livoraInput(
                            'Dirección de recojo',
                            hint: 'Arrastra el mapa o escribe la calle y número',
                            icon: Icons.place_outlined,
                          ).copyWith(
                            suffixIcon: _geocodingAddress
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: LivoraColors.forest,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa o confirma la dirección de recojo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // Campo 2: Piso / Departamento / Referencia opcional
                        TextFormField(
                          controller: _referenceController,
                          decoration: livoraInput(
                            'Piso / Dpto / Referencia (opcional)',
                            hint: 'Ej: Dpto 302, timbrar al costado de la bodega',
                            icon: Icons.apartment_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const SectionTitle(text: 'Detalles adicionales'),
                TextFormField(
                  controller: _descriptionController,
                  decoration: livoraInput(
                    'Notas para el recolector (opcional)',
                    hint: 'Ej. Bolsa verde en recepción',
                    icon: Icons.sticky_note_2_outlined,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                BusyButton(
                  label: 'Crear solicitud',
                  icon: Icons.recycling,
                  busy: _busy,
                  onPressed: _totalKg >= 0.5 ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        label: const Text('Añadir foto del material (opcional)'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Miniatura Thumbnail 72x72
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(
                    photo!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                  if (uploading)
                    Container(
                      width: 72,
                      height: 72,
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Estado y Acciones
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        uploaded
                            ? Icons.check_circle
                            : (uploading
                                ? Icons.cloud_upload_outlined
                                : Icons.photo_outlined),
                        color: uploaded ? LivoraColors.green : LivoraColors.slate,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        uploading ? 'Subiendo imagen…' : 'Foto adjunta',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: LivoraColors.deep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Vista previa para el recolector',
                    style: TextStyle(
                      fontSize: 11,
                      color: LivoraColors.ink.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: uploading ? null : onPick,
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text('Cambiar', style: TextStyle(fontSize: 11.5)),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFC0392B),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: uploading ? null : onRemove,
                        icon: const Icon(Icons.delete_outline, size: 15),
                        label: const Text('Eliminar', style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
