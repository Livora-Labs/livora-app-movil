import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../shell/home_shell.dart';
import 'widgets/store_address_selector_bottom_sheet.dart';

/// Flujo de Onboarding Mandatorio para Comercios Aliados (Roles.tienda).
/// Recolecta la identidad fiscal (RUC), física (Dirección + GPS), comercial (Rubro, Fachada)
/// y envía el expediente a evaluación por parte del equipo administrativo de Livora.
class StoreOnboardingScreen extends StatefulWidget {
  const StoreOnboardingScreen({super.key});

  @override
  State<StoreOnboardingScreen> createState() => _StoreOnboardingScreenState();
}

class _StoreOnboardingScreenState extends State<StoreOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cciCtrl = TextEditingController();

  String _selectedCategory = 'Bodega / Minimarket';
  double? _latitude;
  double? _longitude;

  String? _localPhotoPath;
  String? _uploadedPhotoUrl;
  bool _uploadingPhoto = false;
  String? _photoUploadError;

  bool _swornDeclarationAccepted = false;
  bool _submitting = false;

  static const List<String> _commercialCategories = [
    'Bodega / Minimarket',
    'Restaurante / Comida',
    'Panadería / Pastelería',
    'Farmacia / Botica',
    'Tienda Ecológica / Granel',
    'Frutería / Verdulería',
    'Cafetería',
    'Comercio / Servicios Generales',
  ];

  @override
  void initState() {
    super.initState();
    _prefillFromSession();
  }

  void _prefillFromSession() {
    final user = context.read<SessionController>().user;
    if (user != null) {
      if (user.name != null && user.name!.isNotEmpty) {
        _businessNameCtrl.text = user.name!;
      }
      if (user.phone != null && user.phone!.isNotEmpty) {
        _phoneCtrl.text = user.phone!;
      }
      if (user.address != null && user.address!.isNotEmpty) {
        _addressCtrl.text = user.address!;
      }
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _rucCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _cciCtrl.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StoreAddressSelectorBottomSheet(
        initialAddress: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
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
          _addressCtrl.text = addr;
        }
      });
      showAppSnack(context, 'Ubicación física del local fijada con éxito');
    }
  }

  Future<bool> _uploadLocalPhoto() async {
    if (_localPhotoPath == null) return false;
    final api = context.read<LivoraApi>();
    setState(() {
      _uploadingPhoto = true;
      _photoUploadError = null;
    });

    try {
      final file = File(_localPhotoPath!);
      if (!await file.exists()) {
        throw Exception('El archivo de imagen no existe en el almacenamiento');
      }

      // Usar 'collection' para persistencia directa en el bucket público livora-uploads
      final remoteUrl = await api.uploadFile(
        filePath: _localPhotoPath!,
        purpose: 'collection',
      );

      if (mounted) {
        setState(() {
          _uploadedPhotoUrl = remoteUrl;
          _uploadingPhoto = false;
          _photoUploadError = null;
        });
        showAppSnack(context, 'Fotografía de la fachada subida con éxito');
        return true;
      }
      return false;
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _photoUploadError = e.message;
        });
        showAppSnack(context, 'Error al subir fotografía: ${e.message}', error: true);
      }
      return false;
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _uploadingPhoto = false;
          _photoUploadError = msg;
        });
        showAppSnack(context, 'Error al procesar la fotografía: $msg', error: true);
      }
      return false;
    }
  }

  Future<void> _pickStorePhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked != null && mounted) {
        setState(() {
          _localPhotoPath = picked.path;
          _uploadedPhotoUrl = null;
          _photoUploadError = null;
        });

        await _uploadLocalPhoto();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        showAppSnack(context, 'Error al acceder a la cámara o galería: $e', error: true);
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

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    final api = context.read<LivoraApi>();
    final session = context.read<SessionController>();

    if (_uploadedPhotoUrl == null || _uploadedPhotoUrl!.isEmpty) {
      if (_localPhotoPath != null) {
        showAppSnack(context, 'Subiendo fotografía de fachada capturada...');
        final ok = await _uploadLocalPhoto();
        if (!mounted) return;
        if (!ok || _uploadedPhotoUrl == null || _uploadedPhotoUrl!.isEmpty) {
          showAppSnack(
            context,
            'No se pudo subir la fotografía de la fachada. Por favor pulsa "Reintentar Subida".',
            error: true,
          );
          return;
        }
      } else {
        showAppSnack(context, 'Debes subir una fotografía de la fachada física de tu local', error: true);
        return;
      }
    }

    if (!_swornDeclarationAccepted) {
      showAppSnack(context, 'Debes aceptar la declaración jurada de veracidad comercial', error: true);
      return;
    }

    await HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() => _submitting = true);

    try {
      await api.submitStoreKycApplication(
        businessName: _businessNameCtrl.text.trim(),
        ruc: _rucCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        documentUrl: _uploadedPhotoUrl!,
        bankCci: _cciCtrl.text.trim().isNotEmpty ? _cciCtrl.text.trim() : null,
        latitude: _latitude,
        longitude: _longitude,
        phone: _phoneCtrl.text.trim(),
      );

      // Actualizar estado KYC en sesión
      session.updateKycStatus(KycStatus.pending);

      if (!mounted) return;
      setState(() => _submitting = false);

      // Mostrar diálogo corporativo de confirmación
      await _showSuccessDialog();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showAppSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        showAppSnack(context, 'Ocurrió un error al procesar tu afiliación. Intenta nuevamente.', error: true);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: LivoraColors.green.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.mark_email_read_rounded, color: LivoraColors.forest, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Expediente Enviado a Evaluación',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: LivoraColors.deep,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Los datos de tu comercio y RUC han ingresado a revisión administrativa por el equipo de Livora.\n\nPuedes ingresar a tu panel para explorar las herramientas mientras validamos tu expediente (plazo estimado: 24h a 48h hábiles).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: LivoraColors.slate,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: LivoraColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Ingresar a mi Panel Comercial',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Saldrás del formulario de afiliación comercial y deberás volver a iniciar sesión para continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar', style: TextStyle(color: LivoraColors.slate)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LivoraColors.coral),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final session = context.read<SessionController>();
      await session.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Afiliación de Comercio',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded, color: LivoraColors.slate),
            onPressed: _confirmLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // Hero Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF003B2B), Color(0xFF006852)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: LivoraColors.deep.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bienvenido a Livora Comercios',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Completa los datos de tu establecimiento para emitir cobros por QR y recibir liquidaciones.',
                            style: TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECCIÓN 1: Identidad Fiscal y Comercial
              _buildSectionTitle(
                title: '1. Identidad Fiscal y Comercial',
                subtitle: 'Datos registrados ante la SUNAT para cobros y facturación',
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _businessNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: livoraInput(
                  'Razón Social o Nombre Comercial',
                  hint: 'Ej. Bodega San Martín SAC',
                  icon: Icons.business_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la razón social o nombre comercial' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _rucCtrl,
                keyboardType: TextInputType.number,
                maxLength: 11,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: livoraInput(
                  'Número de RUC (11 dígitos)',
                  hint: 'Ej. 10456789123 o 20601234567',
                  icon: Icons.badge_outlined,
                  helper: 'RUC 10 (persona con negocio) o 20 (empresa jurídica) activo en SUNAT.',
                ),
                validator: validateRuc,
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: livoraInput(
                  'Rubro Comercial',
                  icon: Icons.category_outlined,
                ),
                items: _commercialCategories.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 24),

              // SECCIÓN 2: Ubicación Física del Establecimiento
              _buildSectionTitle(
                title: '2. Ubicación Física del Establecimiento',
                subtitle: 'Dirección donde los hogares podrán escanear tu QR y canjear',
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: livoraInput(
                  'Dirección Comercial del Local',
                  hint: 'Ej. Av. Larco 450, Miraflores, Lima',
                  icon: Icons.location_on_outlined,
                  helper: 'Indica avenida, calle, número y distrito exacto.',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la dirección exacta de tu local' : null,
              ),
              const SizedBox(height: 12),

              // Botón de georreferenciación y mapa del local
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _openLocationPicker,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _latitude != null ? LivoraColors.mint.withValues(alpha: 0.35) : LivoraColors.paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _latitude != null ? LivoraColors.green.withValues(alpha: 0.5) : LivoraColors.border,
                      width: _latitude != null ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _latitude != null ? Icons.check_circle_rounded : Icons.add_location_alt_outlined,
                        color: _latitude != null ? LivoraColors.green : LivoraColors.forest,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latitude != null ? 'Ubicación Comercial Verificada' : 'Georreferenciación Comercial',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _latitude != null
                                  ? (_addressCtrl.text.isNotEmpty ? _addressCtrl.text : 'Punto comercial fijado en el mapa')
                                  : 'Fija el local en el mapa para que los hogares canjeen en tu tienda',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _latitude != null ? LivoraColors.forest : LivoraColors.slate,
                                fontWeight: _latitude != null ? FontWeight.w600 : FontWeight.w400,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: LivoraColors.forest,
                          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                        onPressed: _openLocationPicker,
                        child: Text(_latitude != null ? 'Cambiar' : 'Fijar Ubicación'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: livoraInput(
                  'Teléfono de Contacto Comercial',
                  hint: 'Ej. 987654321',
                  icon: Icons.phone_android_rounded,
                  helper: 'Línea móvil activa para notificaciones y soporte operativo.',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa el teléfono comercial';
                  final clean = v.replaceAll(RegExp(r'\D'), '');
                  if (clean.length != 9 || !clean.startsWith('9')) {
                    return 'Ingresa un celular peruano válido (9 dígitos comenzando con 9)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // SECCIÓN 3: Fachada Física y Cuenta de Liquidación
              _buildSectionTitle(
                title: '3. Fotografía de Fachada y Cuenta de Retiros',
                subtitle: 'Comprobación visual de local abierto al público y cuenta bancaria',
              ),
              const SizedBox(height: 12),

              // Fotografía de fachada
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LivoraColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _uploadedPhotoUrl != null ? LivoraColors.green : LivoraColors.border,
                    width: _uploadedPhotoUrl != null ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    if (_localPhotoPath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_localPhotoPath!),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Icon(
                          _uploadedPhotoUrl != null ? Icons.verified_rounded : Icons.add_a_photo_outlined,
                          color: _uploadedPhotoUrl != null ? LivoraColors.green : LivoraColors.forest,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _uploadedPhotoUrl != null
                                    ? 'Fotografía de Fachada Cargada'
                                    : 'Foto del Frontis / Fachada del Local *',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _uploadedPhotoUrl != null
                                    ? 'Archivo verificado y alojado en almacenamiento seguro'
                                    : 'Debe mostrar el letrero comercial o puerta de atención',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _uploadedPhotoUrl != null ? LivoraColors.forest : LivoraColors.slate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_uploadingPhoto) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(color: LivoraColors.forest),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Subiendo fotografía al servidor seguro...',
                          style: TextStyle(fontSize: 11.5, color: LivoraColors.forest, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ] else if (_localPhotoPath != null && _uploadedPhotoUrl == null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: LivoraColors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: LivoraColors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 18, color: LivoraColors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _photoUploadError != null
                                    ? 'Error de subida: $_photoUploadError'
                                    : 'Foto capturada pero no se pudo subir. Pulsa reintentar.',
                                style: const TextStyle(fontSize: 11.5, color: LivoraColors.amber, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LivoraColors.forest,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                              label: const Text('Reintentar Subida', style: TextStyle(fontWeight: FontWeight.w700)),
                              onPressed: _uploadLocalPhoto,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LivoraColors.slate,
                              side: const BorderSide(color: LivoraColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Cambiar'),
                            onPressed: _showPhotoOptions,
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LivoraColors.forest,
                            side: const BorderSide(color: LivoraColors.forest),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: Icon(_uploadedPhotoUrl != null ? Icons.refresh_rounded : Icons.camera_alt_outlined, size: 18),
                          label: Text(_uploadedPhotoUrl != null ? 'Cambiar Fotografía' : 'Tomar / Subir Fotografía'),
                          onPressed: _showPhotoOptions,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _cciCtrl,
                keyboardType: TextInputType.number,
                maxLength: 20,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: livoraInput(
                  'Código de Cuenta Interbancaria (CCI - 20 dígitos)',
                  hint: 'Ej. 00219400123456789012',
                  icon: Icons.account_balance_outlined,
                  helper: 'Opcional para iniciar. Requerido para transferirte los Soles en liquidaciones.',
                ),
                validator: validateOptionalCci,
              ),
              const SizedBox(height: 20),

              // Declaración Jurada de Veracidad (Ley 29571)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: LivoraColors.border),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: LivoraColors.forest,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _swornDeclarationAccepted,
                  onChanged: (val) {
                    setState(() => _swornDeclarationAccepted = val ?? false);
                  },
                  title: const Text(
                    'Declaro bajo juramento que los datos comerciales ingresados son verídicos, corresponden a un establecimiento físico en funcionamiento y autorizo a Livora a validar el RUC ante la SUNAT conforme a la Ley N.° 29571.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: LivoraColors.deep),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Botón de Envío
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: LivoraColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submitting ? null : _submitOnboarding,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Enviar Solicitud de Afiliación Comercial',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: LivoraColors.deep,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: LivoraColors.slate,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
