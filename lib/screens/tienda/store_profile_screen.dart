import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_shimmer.dart';
import 'widgets/store_address_selector_bottom_sheet.dart';

/// Pantalla de Perfil Comercial y Verificación KYC para el rol TIENDA.
/// Valida datos fiscales estrictos bajo regulación peruana (RUC 10/20, CCI de 20 dígitos y foto de fachada).
class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _rucController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankAccountController = TextEditingController();

  double? _latitude;
  double? _longitude;

  String? _logoUrl;
  String? _localPhotoPath;
  bool _uploadingPhoto = false;

  bool _loading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _rucController.dispose();
    _addressController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = context.read<SessionController>().user;
      if (user != null) {
        _latitude = user.latitude;
        _longitude = user.longitude;
      }

      final api = context.read<LivoraApi>();
      final profile = await api.getStoreProfile();
      if (profile != null && mounted) {
        _businessNameController.text = profile['businessName']?.toString() ?? '';
        _rucController.text = profile['ruc']?.toString() ?? '';
        _addressController.text = profile['address']?.toString() ?? '';
        _bankAccountController.text = profile['bankAccount']?.toString() ?? '';
        _logoUrl = profile['logoUrl']?.toString();
      }
    } on ApiException catch (e) {
      if (e.statusCode != 404 && mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      // Manejo silencioso de nuevo perfil
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLocationPicker() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StoreAddressSelectorBottomSheet(
        initialAddress: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        initialLat: _latitude,
        initialLng: _longitude,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = (result['latitude'] as num).toDouble();
        _longitude = (result['longitude'] as num).toDouble();
        final addr = result['address'] as String?;
        if (addr != null && addr.trim().isNotEmpty) {
          _addressController.text = addr;
        }
      });
      showAppSnack(context, 'Ubicación comercial seleccionada correctamente');
    }
  }

  bool get _isStoreVerified {
    final rucValid = validateRuc(_rucController.text) == null;
    final cciValid = validateOptionalCci(_bankAccountController.text) == null;
    final nameValid = _businessNameController.text.trim().isNotEmpty;
    final addrValid = _addressController.text.trim().isNotEmpty;
    final hasPhoto = (_logoUrl != null && _logoUrl!.isNotEmpty) || _localPhotoPath != null;
    return rucValid && cciValid && nameValid && addrValid && hasPhoto;
  }

  Future<void> _pickStorePhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked != null && mounted) {
        setState(() {
          _localPhotoPath = picked.path;
          _uploadingPhoto = true;
        });

        final api = context.read<LivoraApi>();
        final remoteUrl = await api.uploadFile(
          filePath: picked.path,
          purpose: 'collection',
        );

        if (mounted) {
          setState(() {
            _logoUrl = remoteUrl;
            _uploadingPhoto = false;
          });
          showAppSnack(context, 'Foto de la fachada cargada con éxito');
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        showAppSnack(context, 'Error al subir la fotografía: ${e.message}', error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        showAppSnack(context, 'Error al procesar la fotografía: $e', error: true);
      }
    }
  }

  void _showPhotoOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: LivoraColors.forest),
                title: const Text('Tomar foto con la cámara', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickStorePhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: LivoraColors.forest),
                title: const Text('Elegir de la galería', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickStorePhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final api = context.read<LivoraApi>();
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _busy = true);

    try {
      await api.updateStoreProfile(
        businessName: _businessNameController.text.trim(),
        ruc: _rucController.text.trim(),
        address: _addressController.text.trim(),
        bankAccount: _bankAccountController.text.trim(),
        logoUrl: _logoUrl,
      );

      if (_latitude != null || _longitude != null) {
        await api.updateProfile(
          name: _businessNameController.text.trim(),
          address: _addressController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
        ).catchError((_) => <String, dynamic>{});
      }

      if (mounted) {
        showAppSnack(context, 'Perfil comercial guardado con éxito');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al guardar el perfil comercial', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _isStoreVerified;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Comercial y KYC'),
      ),
      body: _loading
          ? const LivoraShimmerList(
              itemCount: 4,
              padding: EdgeInsets.fromLTRB(20, 16, 20, 80),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Escudo de Verificación Comercial
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? LivoraColors.green.withValues(alpha: 0.08)
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isVerified
                              ? LivoraColors.green.withValues(alpha: 0.3)
                              : Colors.amber.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isVerified
                                  ? LivoraColors.green.withValues(alpha: 0.15)
                                  : Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isVerified ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                              color: isVerified ? LivoraColors.green : Colors.amber.shade900,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVerified
                                      ? 'Comercio Verificado en Livora'
                                      : 'Verificación Comercial Pendiente',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isVerified ? LivoraColors.green : Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isVerified
                                      ? 'Tus datos fiscales, bancarios y ubicación están 100% operativos para cobros y retiros.'
                                      : 'Completa tu RUC, CCI bancario y fotografía del local para habilitar liquidaciones bancarias.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isVerified ? LivoraColors.deep : Colors.amber.shade900,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Fotografía de la Fachada / Local Físico
                    const Text(
                      'Fotografía de la Fachada del Local',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Esta fotografía se exhibirá en el mapa y directorio para que los vecinos reconozcan tu tienda.',
                      style: TextStyle(fontSize: 12, color: LivoraColors.slate),
                    ),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: _uploadingPhoto ? null : _showPhotoOptions,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: LivoraColors.paper,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LivoraColors.border, width: 1.5),
                        ),
                        child: _uploadingPhoto
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: LivoraColors.forest),
                                    SizedBox(height: 8),
                                    Text('Comprimiendo y subiendo foto…', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              )
                            : _localPhotoPath != null
                                ? GestureDetector(
                                    onTap: () {
                                      showMediaViewerDialog(
                                        context,
                                        _localPhotoPath!,
                                        title: 'Fachada del Local',
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.file(
                                        File(_localPhotoPath!),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                  )
                                : _logoUrl != null && _logoUrl!.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          showMediaViewerDialog(
                                            context,
                                            _logoUrl!,
                                            title: 'Fachada del Local',
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: CachedNetworkImage(
                                            imageUrl: _logoUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            placeholder: (_, __) => const Center(
                                              child: CircularProgressIndicator(color: LivoraColors.forest),
                                            ),
                                            errorWidget: (_, __, ___) => const Center(
                                              child: Icon(Icons.storefront_rounded, size: 40, color: LivoraColors.slate),
                                            ),
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_a_photo_outlined, size: 36, color: LivoraColors.forest),
                                            SizedBox(height: 8),
                                            Text(
                                              'Subir foto de la fachada o letrero',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: LivoraColors.forest,
                                              ),
                                            ),
                                            Text(
                                              'Cámara o Galería',
                                              style: TextStyle(fontSize: 11, color: LivoraColors.slate),
                                            ),
                                          ],
                                        ),
                                      ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo Razón Social
                    TextFormField(
                      controller: _businessNameController,
                      decoration: livoraInput(
                        'Razón Social / Nombre Comercial',
                        icon: Icons.store_outlined,
                        hint: 'Mi Bodega Don Pepe',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa la razón social o nombre comercial'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Campo RUC (11 dígitos, inicia con 10 o 20)
                    TextFormField(
                      controller: _rucController,
                      decoration: livoraInput(
                        'RUC (11 dígitos)',
                        icon: Icons.badge_outlined,
                        hint: '10708912345',
                        helper: 'RUC 10 (Persona Natural con Negocio) o RUC 20 (Empresa).',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: kRucInputFormatters,
                      validator: validateRuc,
                    ),
                    const SizedBox(height: 18),

                    // Campo Dirección Comercial
                    TextFormField(
                      controller: _addressController,
                      decoration: livoraInput(
                        'Dirección Comercial',
                        icon: Icons.location_on_outlined,
                        hint: 'Av. Larco 123, Miraflores, Lima',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa la dirección física de la tienda'
                          : null,
                    ),
                    const SizedBox(height: 10),

                    // Selector interactivo de mapa y GPS para Tienda
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openLocationPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _latitude != null ? LivoraColors.mint.withValues(alpha: 0.3) : LivoraColors.paper,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _latitude != null ? LivoraColors.green.withValues(alpha: 0.4) : LivoraColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _latitude != null ? Icons.check_circle_rounded : Icons.add_location_alt_outlined,
                              color: _latitude != null ? LivoraColors.green : LivoraColors.forest,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _latitude != null
                                    ? 'Ubicación comercial fijada en el mapa'
                                    : 'Fijar o calibrar ubicación en el mapa',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _latitude != null ? LivoraColors.forest : LivoraColors.slate,
                                ),
                              ),
                            ),
                            Text(
                              _latitude != null ? 'Cambiar' : 'Fijar',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: LivoraColors.forest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Campo Cuenta Bancaria CCI (opcional para inicio, requerido para liquidación)
                    TextFormField(
                      controller: _bankAccountController,
                      decoration: livoraInput(
                        'Código de Cuenta Interbancario (CCI - 20 dígitos)',
                        icon: Icons.account_balance_outlined,
                        hint: '00219100000000000012',
                        helper: 'Opcional. Requerido para transferirte los Soles en liquidaciones.',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: kCciInputFormatters,
                      validator: validateOptionalCci,
                    ),
                    const SizedBox(height: 32),

                    // Botón Principal BusyButton con respuesta háptica
                    BusyButton(
                      label: 'Guardar Perfil Comercial',
                      icon: Icons.save_rounded,
                      busy: _busy,
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
