import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';

/// Pantalla exclusiva de Verificación de Identidad (KYC) para el rol Hogar.
/// Desacoplada al 100% de cualquier requisito operativo de recolectores (cero vehículos, cero placas).
/// Diseñada con lenguaje residencial y validación legal bajo la Ley N.º 29733.
class HogarKycScreen extends StatefulWidget {
  const HogarKycScreen({super.key});

  @override
  State<HogarKycScreen> createState() => _HogarKycScreenState();
}

class _HogarKycScreenState extends State<HogarKycScreen> {
  // Documento Frontal
  String? _documentUrl;
  String? _filePath;
  String? _fileName;
  bool _uploading = false;
  double _uploadProgress = 0.0;

  // Documento Reverso (Opcional)
  String? _documentBackUrl;
  String? _fileBackPath;
  String? _fileBackName;
  bool _uploadingBack = false;
  double _uploadProgressBack = 0.0;

  // Selfie Facial
  String? _selfieUrl;
  String? _selfiePath;
  bool _uploadingSelfie = false;
  double _uploadProgressSelfie = 0.0;

  final _docNumberCtrl = TextEditingController();

  bool _sending = false;

  KycApplication? _application;
  String? _loadError;
  bool _loading = true;

  bool get _isPdf => (_fileName ?? '').toLowerCase().endsWith('.pdf');
  bool get _canSubmit => _application?.canSubmit ?? true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final application = await context.read<LivoraApi>().kycApplication();
      if (mounted) {
        context.read<SessionController>().updateKycStatus(application.kycStatus);
        setState(() {
          _application = application;
          _loadError = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadDocument(String path, String name, {bool isBack = false}) async {
    final api = context.read<LivoraApi>();
    final file = File(path);
    final size = await file.length();
    if (!mounted) return;

    if (size > 10 * 1024 * 1024) {
      showAppSnack(
        context,
        'El archivo pesa demasiado. Sube una foto o PDF menor a 10 MB.',
        error: true,
      );
      return;
    }

    setState(() {
      if (isBack) {
        _fileBackPath = path;
        _fileBackName = name;
        _documentBackUrl = null;
        _uploadingBack = true;
        _uploadProgressBack = 0.15;
      } else {
        _filePath = path;
        _fileName = name;
        _documentUrl = null;
        _uploading = true;
        _uploadProgress = 0.05;
      }
    });

    try {
      final url = await api.uploadFile(
        filePath: path,
        purpose: 'kyc',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              if (isBack) {
                _uploadProgressBack = progress;
              } else {
                _uploadProgress = progress;
              }
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          if (isBack) {
            _documentBackUrl = url;
            _uploadProgressBack = 1.0;
          } else {
            _documentUrl = url;
            _uploadProgress = 1.0;
          }
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, 'Error al subir documento: ${error.message}', error: true);
        setState(() {
          if (isBack) {
            _fileBackPath = null;
            _fileBackName = null;
          } else {
            _filePath = null;
            _fileName = null;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isBack) {
            _uploadingBack = false;
          } else {
            _uploading = false;
          }
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source, {bool isBack = false}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _uploadDocument(picked.path, picked.name, isBack: isBack);
    } on PlatformException catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Permiso denegado para acceder a la cámara o galería.',
          error: true,
          actionLabel: 'Ajustes',
          onAction: () => LocationService.openAppSettings(),
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al seleccionar la imagen.', error: true);
      }
    }
  }

  Future<void> _pickPdf({bool isBack = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;
      await _uploadDocument(file.path!, file.name, isBack: isBack);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al seleccionar el PDF.', error: true);
      }
    }
  }

  Future<void> _showDocumentSourceSheet({bool isBack = false}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: LivoraColors.forest),
              title: Text(isBack ? 'Fotografiar reverso del documento' : 'Fotografiar anverso del documento'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: LivoraColors.blue),
              title: const Text('Elegir imagen de la galería'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFC53030)),
              title: const Text('Adjuntar documento en PDF'),
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'camera':
        await _pickImage(ImageSource.camera, isBack: isBack);
      case 'gallery':
        await _pickImage(ImageSource.gallery, isBack: isBack);
      case 'pdf':
        await _pickPdf(isBack: isBack);
    }
  }

  Future<void> _pickSelfie() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _uploadSelfie(picked.path);
    } on PlatformException catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo acceder a la cámara frontal para la selfie.',
          error: true,
          actionLabel: 'Ajustes',
          onAction: () => LocationService.openAppSettings(),
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al capturar la fotografía facial', error: true);
      }
    }
  }

  Future<void> _uploadSelfie(String path) async {
    final api = context.read<LivoraApi>();
    setState(() {
      _selfiePath = path;
      _selfieUrl = null;
      _uploadingSelfie = true;
      _uploadProgressSelfie = 0.05;
    });

    try {
      final url = await api.uploadFile(
        filePath: path,
        purpose: 'kyc',
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgressSelfie = progress);
        },
      );
      if (mounted) {
        setState(() {
          _selfieUrl = url;
          _uploadProgressSelfie = 1.0;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, 'Error al subir selfie: ${error.message}', error: true);
        setState(() => _selfiePath = null);
      }
    } finally {
      if (mounted) setState(() => _uploadingSelfie = false);
    }
  }

  Future<void> _submit() async {
    if (_selfieUrl == null) {
      showAppSnack(
        context,
        'Debes tomarte una selfie clara para validar tu identidad.',
        error: true,
      );
      return;
    }
    if (_documentUrl == null) {
      showAppSnack(
        context,
        'Debes adjuntar tu documento de identidad (DNI o Carné de Extranjería).',
        error: true,
      );
      return;
    }
    if (_docNumberCtrl.text.trim().isEmpty) {
      showAppSnack(
        context,
        'Ingresa el número de tu DNI o Carné de Extranjería.',
        error: true,
      );
      return;
    }

    setState(() => _sending = true);
    final api = context.read<LivoraApi>();
    final session = context.read<SessionController>();
    try {
      // Envío especializado: solo datos personales residenciales, CERO vehículos ni placas
      await api.submitKycApplication(
            _documentUrl!,
            selfieUrl: _selfieUrl,
            documentUrlBack: _documentBackUrl,
            documentNumber: _docNumberCtrl.text.trim(),
          );
      if (session.user != null) {
        await session.updateUser(
          session.user!.copyWith(
            dniDocumentNumber: _docNumberCtrl.text.trim(),
            dniPhotoUrl: _documentUrl,
            profilePhotoUrl: _selfieUrl,
            kycStatus: KycStatus.pending,
          ),
        );
      } else {
        session.updateKycStatus(KycStatus.pending);
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            color: LivoraColors.green,
            size: 44,
          ),
          title: const Text('Verificación Residencial Enviada'),
          content: const Text(
            'Tu documento de identidad y selfie han sido recibidos con éxito.\n\nEl equipo de Livora validará tus credenciales para habilitar tu insignia de Hogar Verificado y mayores límites de canje LIVO.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                minimumSize: const Size(0, 44),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      _loadStatus();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verificación del Hogar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verificación del Hogar')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFC62828)),
                const SizedBox(height: 12),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _loadStatus, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      );
    }

    final app = _application;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text('Verificación del Hogar'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HogarKycHeader(status: app?.status ?? 'NOT_SUBMITTED'),
            const SizedBox(height: 16),

            // Tracker de Progreso
            _HogarKycStepTracker(status: app?.status ?? 'NOT_SUBMITTED'),
            const SizedBox(height: 20),

            // Si está verificado
            if (app != null && app.isApproved) ...[
              _HogarApprovedCard(application: app),
            ] else if (app != null && app.isPending) ...[
              _HogarPendingCard(application: app),
            ] else if (_canSubmit) ...[
              if (app != null && (app.isRejected || app.isObserved)) ...[
                _HogarRejectedNotice(application: app),
                const SizedBox(height: 16),
              ],
              _buildForm(app),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm(KycApplication? app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PASO 1: SELFIE FACIAL
        const SectionTitle(text: '1. Fotografía de Rostro (Selfie)'),
        const SizedBox(height: 4),
        const Text(
          'Tómate una fotografía clara de frente, sin gorra ni lentes de sol. Se utiliza para validar que el documento te pertenece.',
          style: TextStyle(fontSize: 12.5, color: LivoraColors.slate),
        ),
        const SizedBox(height: 12),

        if (_selfiePath != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_selfieUrl != null) {
                      showMediaViewerDialog(context, _selfieUrl!, title: 'Selfie de Verificación');
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.file(
                      File(_selfiePath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selfie capturada con éxito',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (_uploadingSelfie) ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: _uploadProgressSelfie, color: LivoraColors.forest),
                      ] else ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Lista para verificación',
                          style: TextStyle(fontSize: 11.5, color: LivoraColors.green),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: LivoraColors.slate),
                  tooltip: 'Tomar otra selfie',
                  onPressed: _uploadingSelfie ? null : _pickSelfie,
                ),
              ],
            ),
          ),
        ] else ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: LivoraColors.forest),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.camera_alt_outlined, color: LivoraColors.forest),
            label: const Text(
              'Tomar Selfie con la Cámara Frontal',
              style: TextStyle(color: LivoraColors.forest, fontWeight: FontWeight.bold),
            ),
            onPressed: _pickSelfie,
          ),
        ],

        const SizedBox(height: 24),

        // PASO 2: DOCUMENTO DE IDENTIDAD
        const SectionTitle(text: '2. Documento de Identidad (DNI / Carné)'),
        const SizedBox(height: 4),
        const Text(
          'Sube una fotografía nítida o PDF del anverso y reverso de tu documento oficial emitido en Perú.',
          style: TextStyle(fontSize: 12.5, color: LivoraColors.slate),
        ),
        const SizedBox(height: 12),

        // Anverso
        if (_filePath != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_documentUrl != null && !_isPdf) {
                      showMediaViewerDialog(context, _documentUrl!, title: 'Documento Anverso');
                    }
                  },
                  child: Icon(
                    _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    color: LivoraColors.forest,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_documentUrl != null && !_isPdf) {
                        showMediaViewerDialog(context, _documentUrl!, title: 'Documento Anverso');
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName ?? 'Documento Anverso',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_uploading) ...[
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: _uploadProgress, color: LivoraColors.forest),
                        ] else ...[
                          const SizedBox(height: 2),
                          const Text('Cargado con éxito (Toca para ampliar)', style: TextStyle(fontSize: 11.5, color: LivoraColors.green)),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: _uploading ? null : () => setState(() => _filePath = null),
                ),
              ],
            ),
          ),
        ] else ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.badge_outlined, color: LivoraColors.forest),
            label: const Text('Adjuntar Anverso del Documento (Frente)'),
            onPressed: () => _showDocumentSourceSheet(isBack: false),
          ),
        ],

        const SizedBox(height: 10),

        // Reverso (Opcional)
        if (_fileBackPath != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_documentBackUrl != null) {
                      showMediaViewerDialog(context, _documentBackUrl!, title: 'Documento Reverso');
                    }
                  },
                  child: const Icon(Icons.flip_to_back_rounded, color: LivoraColors.forest, size: 36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_documentBackUrl != null) {
                        showMediaViewerDialog(context, _documentBackUrl!, title: 'Documento Reverso');
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileBackName ?? 'Documento Reverso',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_uploadingBack) ...[
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: _uploadProgressBack, color: LivoraColors.forest),
                        ] else ...[
                          const SizedBox(height: 2),
                          const Text('Cargado con éxito (Toca para ampliar)', style: TextStyle(fontSize: 11.5, color: LivoraColors.green)),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: _uploadingBack ? null : () => setState(() => _fileBackPath = null),
                ),
              ],
            ),
          ),
        ] else ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: BorderSide(color: Colors.grey.shade300, style: BorderStyle.solid),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.flip_to_back_outlined, color: LivoraColors.slate, size: 20),
            label: const Text(
              'Adjuntar Reverso del Documento (Opcional)',
              style: TextStyle(color: LivoraColors.slate, fontSize: 13),
            ),
            onPressed: () => _showDocumentSourceSheet(isBack: true),
          ),
        ],

        const SizedBox(height: 24),

        // PASO 3: NÚMERO DE DOCUMENTO
        const SectionTitle(text: '3. Datos del Titular Residencial'),
        const SizedBox(height: 12),
        TextField(
          controller: _docNumberCtrl,
          keyboardType: TextInputType.number,
          maxLength: 12,
          decoration: InputDecoration(
            labelText: 'Número de DNI o Carné de Extranjería',
            hintText: 'Ej. 72849102',
            counterText: '',
            prefixIcon: const Icon(Icons.numbers_rounded, color: LivoraColors.forest),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),

        const SizedBox(height: 24),

        // BOTÓN PRINCIPAL DE ENVÍO
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: LivoraColors.forest,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            (app != null && (app.isRejected || app.isObserved))
                ? 'Reenviar Verificación'
                : 'Enviar Verificación',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onPressed: (_documentUrl == null || _selfieUrl == null || _uploading || _uploadingSelfie || _sending)
              ? null
              : _submit,
        ),
        const SizedBox(height: 12),
        const Text(
          'Ley N.º 29733: Tus datos personales son tratados con estricta confidencialidad para fines exclusivos de prevención de fraudes y canjes de recompensas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, height: 1.35, color: LivoraColors.slate),
        ),
      ],
    );
  }
}

class _HogarKycHeader extends StatelessWidget {
  const _HogarKycHeader({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LivoraColors.forest.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_outlined, color: LivoraColors.forest, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hogar Eco-Responsable',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: LivoraColors.deep),
                ),
                SizedBox(height: 2),
                Text(
                  'Verificación de identidad oficial para desbloquear beneficios y canjes en comercios.',
                  style: TextStyle(fontSize: 12, color: LivoraColors.slate, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HogarKycStepTracker extends StatelessWidget {
  const _HogarKycStepTracker({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final isObserved = status == 'observed';

    int activeStep = 0;
    if (isApproved) {
      activeStep = 2;
    } else if (isPending || isObserved || isRejected) {
      activeStep = 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _StepCircle(
            number: '1',
            label: 'Registro',
            isActive: true,
            isCurrent: activeStep == 0,
            isCompleted: activeStep > 0,
          ),
          Expanded(
            child: Container(
              height: 2.5,
              color: isObserved
                  ? const Color(0xFFD97706)
                  : (activeStep >= 1 ? LivoraColors.forest : const Color(0xFFE2E8F0)),
            ),
          ),
          _StepCircle(
            number: '2',
            label: isRejected
                ? 'Rechazado'
                : (isObserved ? 'Observado' : (isPending ? 'En revisión' : 'Documentos')),
            isActive: activeStep >= 1 || isRejected,
            isCurrent: activeStep == 1,
            isCompleted: activeStep > 1,
            isError: isRejected,
            isWarning: isObserved,
          ),
          Expanded(
            child: Container(
              height: 2.5,
              color: activeStep >= 2 ? LivoraColors.green : const Color(0xFFE2E8F0),
            ),
          ),
          _StepCircle(
            number: '3',
            label: 'Verificado',
            isActive: activeStep >= 2,
            isCurrent: activeStep == 2,
            isCompleted: activeStep == 2,
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isCurrent,
    required this.isCompleted,
    this.isError = false,
    this.isWarning = false,
  });

  final String number;
  final String label;
  final bool isActive;
  final bool isCurrent;
  final bool isCompleted;
  final bool isError;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    if (isError) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    } else if (isWarning) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (isCompleted) {
      bg = LivoraColors.green;
      fg = Colors.white;
    } else if (isCurrent) {
      bg = LivoraColors.forest;
      fg = Colors.white;
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF94A3B8);
    }

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: LivoraColors.forest, width: 2) : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : (isError
                    ? const Icon(Icons.close, size: 18, color: Color(0xFFDC2626))
                    : (isWarning
                        ? const Icon(Icons.priority_high, size: 16, color: Color(0xFFD97706))
                        : Text(number, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13)))),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent || isCompleted ? FontWeight.bold : FontWeight.w500,
            color: isError
                ? const Color(0xFFDC2626)
                : (isWarning ? const Color(0xFFD97706) : (isActive ? LivoraColors.deep : const Color(0xFF94A3B8))),
          ),
        ),
      ],
    );
  }
}

class _HogarApprovedCard extends StatelessWidget {
  const _HogarApprovedCard({required this.application});
  final KycApplication application;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LivoraColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0x1F2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: LivoraColors.green, size: 48),
          ),
          const SizedBox(height: 14),
          const Text(
            'Identidad de Hogar Verificada',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: LivoraColors.deep),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu documento y perfil han sido validados exitosamente conforme a ley.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: LivoraColors.slate, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const _HogarBenefitRow(icon: Icons.check_circle_outline, text: 'Canjes y pagos ilimitados en comercios aliados con QR'),
          const _HogarBenefitRow(icon: Icons.check_circle_outline, text: 'Atención prioritaria de recolectores para recojos domiciliarios'),
          const _HogarBenefitRow(icon: Icons.check_circle_outline, text: 'Insignia verde oficial visible en tus solicitudes de reciclaje'),
        ],
      ),
    );
  }
}

class _HogarPendingCard extends StatelessWidget {
  const _HogarPendingCard({required this.application});
  final KycApplication application;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0x1FF59E0B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 48),
          ),
          const SizedBox(height: 14),
          const Text(
            'Verificación en Revisión',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: LivoraColors.deep),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tus documentos están siendo revisados por nuestro equipo. El proceso suele tomar entre 2 y 24 horas hábiles. Recibirás una notificación en cuanto se complete.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: LivoraColors.slate, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _HogarRejectedNotice extends StatelessWidget {
  const _HogarRejectedNotice({required this.application});
  final KycApplication application;

  @override
  Widget build(BuildContext context) {
    final isObs = application.isObserved;
    final color = isObs ? const Color(0xFFD97706) : const Color(0xFFDC2626);
    final bg = isObs ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isObs ? Icons.warning_amber_rounded : Icons.error_outline_rounded, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isObs ? 'Documentación Observada' : 'Verificación Rechazada',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  application.rejectionReason ?? 'Por favor, sube una foto más nítida de tu documento y una selfie clara con buena luz.',
                  style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HogarBenefitRow extends StatelessWidget {
  const _HogarBenefitRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: LivoraColors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: LivoraColors.ink)),
          ),
        ],
      ),
    );
  }
}
