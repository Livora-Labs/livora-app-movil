import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

/// Verificación de identidad del recolector (KYC):
/// Incluye stepper horizontal de estados, zona de carga con validación (<10MB),
/// barra de progreso porcentual y tarjeta de previsualización enriquecida para JPG/PNG/PDF.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  String? _filePath;
  String? _fileName;
  int _fileSizeBytes = 0;
  String? _documentUrl;
  bool _uploading = false;
  double _uploadProgress = 0.0;

  // Foto de perfil / Selfie obligatoria del recolector (FSM 13)
  String? _selfiePath;
  String? _selfieUrl;
  bool _uploadingSelfie = false;
  double _uploadProgressSelfie = 0.0;

  final _docNumberCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  String _transportType = 'MOTO_CARGA';

  bool _sending = false;

  KycApplication? _application;
  String? _loadError;
  bool _loading = true;
  String? _fileSizeError;

  bool get _isPdf => (_fileName ?? '').toLowerCase().endsWith('.pdf');

  /// Solo mostramos el formulario si nunca se envió, si fue observada o si fue rechazada.
  bool get _canSubmit => _application?.canSubmit ?? false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _plateCtrl.dispose();
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

  Future<void> _upload(String path, String name) async {
    final api = context.read<LivoraApi>();
    final file = File(path);
    final size = await file.length();
    if (!mounted) return;

    // Validación de peso en cliente (< 10 MB)
    if (size > 10 * 1024 * 1024) {
      setState(() => _fileSizeError = 'El archivo pesa demasiado. Sube una foto o PDF menor a 10 MB.');
      showAppSnack(
        context,
        'El archivo pesa demasiado. Sube una foto o PDF menor a 10 MB.',
        error: true,
        icon: Icons.upload_file_outlined,
      );
      return;
    }

    setState(() {
      _fileSizeError = null;
      _filePath = path;
      _fileName = name;
      _fileSizeBytes = size;
      _documentUrl = null;
      _uploading = true;
      _uploadProgress = 0.15;
    });

    // Simulación reactiva de progreso conectada a la transmisión
    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted || !_uploading) {
        timer.cancel();
        return;
      }
      if (_uploadProgress < 0.85) {
        setState(() => _uploadProgress += 0.12);
      }
    });

    try {
      final url = await api.uploadFile(
        filePath: path,
        purpose: 'kyc',
      );
      if (mounted) {
        setState(() {
          _documentUrl = url;
          _uploadProgress = 1.0;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _filePath = null;
          _fileName = null;
          _fileSizeBytes = 0;
          _uploadProgress = 0.0;
        });
        showAppSnack(context, error.message, error: true);
      }
    } finally {
      progressTimer.cancel();
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _upload(picked.path, picked.name);
    } on PlatformException catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo acceder a la ${source == ImageSource.camera ? "cámara" : "galería"}. Verifica los permisos del dispositivo.',
          error: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al seleccionar la imagen', error: true);
      }
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final picked = result?.files.single;
      if (picked?.path == null) return;
      await _upload(picked!.path!, picked.name);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al seleccionar el documento PDF', error: true);
      }
    }
  }

  Future<void> _chooseSource() async {
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
              title: const Text('Fotografiar documento con la cámara'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: LivoraColors.blue),
              title: const Text('Elegir imagen de la galería'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFC53030)),
              title: const Text('Adjuntar documento PDF'),
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'camera':
        await _pickImage(ImageSource.camera);
      case 'gallery':
        await _pickImage(ImageSource.gallery);
      case 'pdf':
        await _pickPdf();
    }
  }

  void _clearDocument() {
    setState(() {
      _filePath = null;
      _fileName = null;
      _fileSizeBytes = 0;
      _documentUrl = null;
      _uploadProgress = 0.0;
      _fileSizeError = null;
    });
  }

  void _clearSelfie() {
    setState(() {
      _selfiePath = null;
      _selfieUrl = null;
      _uploadProgressSelfie = 0.0;
    });
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
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al capturar la fotografía de perfil', error: true);
      }
    }
  }

  Future<void> _uploadSelfie(String path) async {
    final api = context.read<LivoraApi>();
    setState(() {
      _selfiePath = path;
      _selfieUrl = null;
      _uploadingSelfie = true;
      _uploadProgressSelfie = 0.2;
    });

    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted || !_uploadingSelfie) {
        timer.cancel();
        return;
      }
      if (_uploadProgressSelfie < 0.85) {
        setState(() => _uploadProgressSelfie += 0.15);
      }
    });

    try {
      final url = await api.uploadFile(
        filePath: path,
        purpose: 'kyc_selfie',
      );
      if (mounted) {
        setState(() {
          _selfieUrl = url;
          _uploadProgressSelfie = 1.0;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _selfiePath = null;
          _selfieUrl = null;
        });
        showAppSnack(context, error.message, error: true);
      }
    } finally {
      progressTimer.cancel();
      if (mounted) setState(() => _uploadingSelfie = false);
    }
  }

  Future<void> _openPdfPreview() async {
    if (_filePath != null) {
      final uri = Uri.file(_filePath!);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      } catch (_) {}
    }
    if (_documentUrl != null) {
      final uri = Uri.parse(_documentUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _submit() async {
    if (_selfieUrl == null) {
      showAppSnack(
        context,
        'Debes tomarte una foto de perfil obligatoria para que los hogares puedan identificarte al llegar.',
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
        'Ingresa el número de tu documento de identidad.',
        error: true,
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await context.read<LivoraApi>().submitKycApplication(
            _documentUrl!,
            selfieUrl: _selfieUrl,
            documentNumber: _docNumberCtrl.text.trim(),
            transportType: _transportType,
            vehiclePlate: _plateCtrl.text.trim().isNotEmpty ? _plateCtrl.text.trim() : null,
          );
      if (!mounted) return;
      context.read<SessionController>().updateKycStatus(KycStatus.pending);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            color: LivoraColors.green,
            size: 44,
          ),
          title: const Text('Solicitud Enviada para Revisión'),
          content: const Text(
            'Tu selfie de perfil y documento de identidad han sido cargados con éxito. El equipo de administración revisará tus credenciales para habilitar tus recolecciones en calle.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
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
      if (mounted) {
        _clearDocument();
        _clearSelfie();
        await _loadStatus();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _application;

    return Scaffold(
      appBar: AppBar(title: const Text('Verificación de Identidad')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStatus,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadError != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off, color: Color(0xFF8C3A3A)),
                    title: Text(_loadError!, style: const TextStyle(fontSize: 13)),
                    trailing: TextButton(
                      onPressed: _loadStatus,
                      child: const Text('Reintentar'),
                    ),
                  ),
                )
              else ...[
                // STEPPER DE ESTADO (KycStatusStepper)
                KycStatusStepper(status: app?.status ?? 'NOT_SUBMITTED'),
                const SizedBox(height: 16),

                // Tarjeta con descripción de estado y avisos
                _StatusCard(application: app!),
                const SizedBox(height: 16),

                if (_canSubmit) ...[
                  const SectionTitle(text: '1. Fotografía de Perfil (Selfie)'),
                  const SizedBox(height: 6),
                  Text(
                    'Obligatorio. Se mostrará en la credencial virtual del hogar cuando estés en camino y al llegar a su puerta.',
                    style: TextStyle(
                      fontSize: 12,
                      color: LivoraColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelfieUploadCard(
                    selfiePath: _selfiePath,
                    selfieUrl: _selfieUrl,
                    uploading: _uploadingSelfie,
                    uploadProgress: _uploadProgressSelfie,
                    onTakeSelfie: _pickSelfie,
                    onDeleteSelfie: _clearSelfie,
                  ),
                  const SizedBox(height: 20),

                  const SectionTitle(text: '2. Documento de Identidad Oficial'),
                  const SizedBox(height: 6),
                  Text(
                    'Sube una fotografía nítida o escaneo PDF de tu DNI o Carné de Extranjería.',
                    style: TextStyle(
                      fontSize: 12,
                      color: LivoraColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ZONA DE SELECCIÓN Y CARGA (DocumentUploadZone)
                  if (_filePath == null)
                    _DocumentUploadZone(
                      onTap: _chooseSource,
                      uploading: _uploading,
                    )
                  else
                    // TARJETA DE PREVISUALIZACIÓN ENRIQUECIDA (KycDocumentPreviewCard)
                    KycDocumentPreviewCard(
                      filePath: _filePath!,
                      fileName: _fileName ?? 'Documento',
                      fileSizeBytes: _fileSizeBytes,
                      isPdf: _isPdf,
                      uploading: _uploading,
                      uploadProgress: _uploadProgress,
                      documentUrl: _documentUrl,
                      onChangeFile: _chooseSource,
                      onDeleteFile: _clearDocument,
                      onOpenPdf: _openPdfPreview,
                    ),

                  if (_fileSizeError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF9E2A2B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fileSizeError!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9E2A2B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const SectionTitle(text: '3. Datos de Operación y Transporte'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _docNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Número de DNI o Carné de Extranjería',
                      hintText: 'Ej. 72849102',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _transportType,
                    decoration: InputDecoration(
                      labelText: 'Medio de Transporte / Recolección',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MOTO_CARGA', child: Text('Motocarga / Mototaxi')),
                      DropdownMenuItem(value: 'TRICICLO', child: Text('Triciclo a pedal')),
                      DropdownMenuItem(value: 'BICICLETA', child: Text('Bicicleta con remolque')),
                      DropdownMenuItem(value: 'CAMIONETA', child: Text('Camioneta / Furgoneta')),
                      DropdownMenuItem(value: 'A_PIE', child: Text('A pie con carrito manual')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _transportType = val);
                    },
                  ),
                  if (_transportType == 'MOTO_CARGA' || _transportType == 'CAMIONETA') ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _plateCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Placa del Vehículo',
                        hintText: 'Ej. 4521-7B o ABC-123',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // CTA PRINCIPAL
                  BusyButton(
                    label: (app.isRejected || app.isObserved) ? 'Reenviar para revisión' : 'Enviar para revisión',
                    icon: Icons.send_rounded,
                    busy: _sending,
                    onPressed: (_documentUrl == null || _selfieUrl == null || _uploading || _uploadingSelfie) ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tipos permitidos: JPG, PNG o PDF. Tamaño máximo: 10 MB.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: LivoraColors.ink.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Stepper horizontal de 3 etapas para el ciclo de vida KYC
class KycStatusStepper extends StatelessWidget {
  const KycStatusStepper({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    // 0: Sin verificar, 1: En revisión / Observado, 2: Verificado
    int activeStep = 0;
    if (status == 'PENDING' || status == 'OBSERVED') activeStep = 1;
    if (status == 'APPROVED') activeStep = 2;

    final isRejected = status == 'REJECTED';
    final isObserved = status == 'OBSERVED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LivoraColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StepCircle(
                number: '1',
                label: 'Sin verificar',
                isActive: activeStep >= 0,
                isCurrent: activeStep == 0,
                isCompleted: activeStep > 0,
              ),
              Expanded(
                child: Container(
                  height: 2.5,
                  color: isObserved
                      ? const Color(0xFFD97706)
                      : (activeStep >= 1 ? LivoraColors.forest : LivoraColors.border),
                ),
              ),
              _StepCircle(
                number: '2',
                label: isRejected
                    ? 'Rechazado'
                    : (isObserved ? 'Observado' : 'En revisión'),
                isActive: activeStep >= 1 || isRejected,
                isCurrent: activeStep == 1,
                isCompleted: activeStep > 1,
                isError: isRejected,
                isWarning: isObserved,
              ),
              Expanded(
                child: Container(
                  height: 2.5,
                  color: activeStep >= 2 ? LivoraColors.green : LivoraColors.border,
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
    Color bg = LivoraColors.paper;
    Color border = LivoraColors.border;
    Color text = LivoraColors.ink.withValues(alpha: 0.5);

    if (isError) {
      bg = const Color(0xFFFDE8E8);
      border = const Color(0xFFC53030);
      text = const Color(0xFFC53030);
    } else if (isWarning) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFD97706);
      text = const Color(0xFFD97706);
    } else if (isCompleted) {
      bg = LivoraColors.green;
      border = LivoraColors.green;
      text = Colors.white;
    } else if (isCurrent) {
      bg = LivoraColors.forest;
      border = LivoraColors.forest;
      text = Colors.white;
    }

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : isError
                    ? const Icon(Icons.close, size: 16, color: Color(0xFFC53030))
                    : isWarning
                        ? const Icon(Icons.priority_high, size: 16, color: Color(0xFFD97706))
                        : Text(
                            number,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                          ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent ? LivoraColors.deep : LivoraColors.ink.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Zona de selección interactiva (DocumentUploadZone)
class _DocumentUploadZone extends StatelessWidget {
  const _DocumentUploadZone({
    required this.onTap,
    required this.uploading,
  });

  final VoidCallback onTap;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: LivoraColors.forest.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: LivoraColors.forest.withValues(alpha: 0.4),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
              child: const Icon(Icons.upload_file_outlined, color: LivoraColors.forest, size: 28),
            ),
            const SizedBox(height: 10),
            const Text(
              'Toca para seleccionar tu documento',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: LivoraColors.deep,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'DNI, Carné de Extranjería o Certificado (JPG, PNG o PDF)',
              style: TextStyle(
                fontSize: 11.5,
                color: LivoraColors.ink.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de previsualización enriquecida con soporte dual (Imagen y PDF) y barra porcentual
class KycDocumentPreviewCard extends StatelessWidget {
  const KycDocumentPreviewCard({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.isPdf,
    required this.uploading,
    required this.uploadProgress,
    required this.documentUrl,
    required this.onChangeFile,
    required this.onDeleteFile,
    required this.onOpenPdf,
  });

  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final bool isPdf;
  final bool uploading;
  final double uploadProgress;
  final String? documentUrl;
  final VoidCallback onChangeFile;
  final VoidCallback onDeleteFile;
  final VoidCallback onOpenPdf;

  @override
  Widget build(BuildContext context) {
    final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Previsualización de Imagen
          if (!isPdf)
            Stack(
              alignment: Alignment.topRight,
              children: [
                Image.file(
                  File(filePath),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                if (uploading)
                  Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 10),
                          Text(
                            'Subiendo... ${(uploadProgress * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Botón eliminar / cambiar
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    radius: 18,
                    child: IconButton(
                      tooltip: 'Eliminar captura',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: uploading ? null : onDeleteFile,
                    ),
                  ),
                ),
              ],
            )
          else
            // Previsualización de PDF
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFFFF5F5),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFC53030),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: LivoraColors.deep,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$sizeMb MB · Formato PDF',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: LivoraColors.ink.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Abrir PDF',
                    icon: const Icon(Icons.open_in_new, color: LivoraColors.deep, size: 20),
                    onPressed: onOpenPdf,
                  ),
                  IconButton(
                    tooltip: 'Eliminar archivo',
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFC53030), size: 20),
                    onPressed: uploading ? null : onDeleteFile,
                  ),
                ],
              ),
            ),

          // Barra de Progreso Porcentual durante la Subida
          if (uploading)
            LinearProgressIndicator(
              value: uploadProgress.clamp(0.0, 1.0),
              backgroundColor: LivoraColors.border,
              color: LivoraColors.forest,
              minHeight: 4,
            ),

          // Pie de Tarjeta con Estado y Acción de Reemplazo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  documentUrl != null ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                  size: 18,
                  color: documentUrl != null ? LivoraColors.green : LivoraColors.forest,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uploading
                        ? 'Cargando archivo (${(uploadProgress * 100).toInt()}%)...'
                        : (documentUrl != null
                            ? 'Archivo listo para enviar'
                            : 'Preparando subida...'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: documentUrl != null ? LivoraColors.green : LivoraColors.deep,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: uploading ? null : onChangeFile,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta con el estado actual de la verificación
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.application});

  final KycApplication application;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, message) = switch (application.status) {
      'APPROVED' => (
        Icons.verified_rounded,
        LivoraColors.green,
        'Identidad Verificada',
        'Tu documentación fue validada por la administración. Ya operas con credenciales oficiales de Recolector Verificado.',
      ),
      'PENDING' => (
        Icons.hourglass_top_rounded,
        const Color(0xFFB7791F),
        'Documentación en Revisión',
        'Un administrador está validando tu fotografía de perfil y documento de identidad. El plazo estimado de respuesta es de 24 a 48 horas.',
      ),
      'OBSERVED' => (
        Icons.warning_amber_rounded,
        const Color(0xFFD97706),
        'Solicitud con Observaciones (${application.retryCount}/3)',
        (application.rejectionReason != null && application.rejectionReason!.isNotEmpty)
            ? 'Observaciones del auditor:\n"${application.rejectionReason}"\n\nPor favor corrige los datos o documentos señalados y vuelve a enviar.'
            : 'Tu documentación presentó observaciones técnicas (borrosa, incompleta o discrepante). Corrige y reenvía.',
      ),
      'REJECTED' => (
        Icons.cancel_rounded,
        const Color(0xFF8C3A3A),
        'Solicitud Rechazada (${application.retryCount}/3)',
        (application.rejectionReason != null && application.rejectionReason!.isNotEmpty)
            ? 'Motivo del rechazo:\n"${application.rejectionReason}"'
            : 'No fue posible validar la documentación presentada. Si aún cuentas con intentos disponibles, puedes volver a postular.',
      ),
      _ => (
        Icons.badge_outlined,
        LivoraColors.forest,
        'Identidad Sin Verificar',
        'Sube tu foto de perfil (selfie) y tu documento de identidad para operar con seguridad y ganar la confianza de los hogares.',
      ),
    };

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12.5, color: LivoraColors.ink),
                  ),
                  if (application.updatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Última actualización: ${fmtDate(application.updatedAt)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: LivoraColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de captura y previsualización de selfie/foto de perfil
class _SelfieUploadCard extends StatelessWidget {
  const _SelfieUploadCard({
    required this.selfiePath,
    required this.selfieUrl,
    required this.uploading,
    required this.uploadProgress,
    required this.onTakeSelfie,
    required this.onDeleteSelfie,
  });

  final String? selfiePath;
  final String? selfieUrl;
  final bool uploading;
  final double uploadProgress;
  final VoidCallback onTakeSelfie;
  final VoidCallback onDeleteSelfie;

  @override
  Widget build(BuildContext context) {
    if (selfiePath == null) {
      return InkWell(
        onTap: uploading ? null : onTakeSelfie,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: LivoraColors.forest.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: LivoraColors.forest.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: LivoraColors.forest.withValues(alpha: 0.12),
                child: const Icon(Icons.face_retouching_natural_rounded, color: LivoraColors.forest, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tomar Foto de Perfil (Selfie)',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: LivoraColors.deep),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Abre la cámara frontal. Se mostrará a los hogares al llegar.',
                      style: TextStyle(fontSize: 11.5, color: LivoraColors.ink),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.camera_alt_outlined, color: LivoraColors.forest),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LivoraColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipOval(
                  child: Image.file(
                    File(selfiePath!),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selfie de Perfil Capturada',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LivoraColors.deep),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        uploading
                            ? 'Subiendo... ${(uploadProgress * 100).toInt()}%'
                            : (selfieUrl != null ? 'Foto cargada correctamente' : 'Preparando subida...'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: selfieUrl != null ? LivoraColors.green : LivoraColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tomar de nuevo',
                  icon: const Icon(Icons.refresh_rounded, color: LivoraColors.forest, size: 20),
                  onPressed: uploading ? null : onTakeSelfie,
                ),
                IconButton(
                  tooltip: 'Eliminar foto',
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFC53030), size: 20),
                  onPressed: uploading ? null : onDeleteSelfie,
                ),
              ],
            ),
          ),
          if (uploading)
            LinearProgressIndicator(
              value: uploadProgress.clamp(0.0, 1.0),
              backgroundColor: LivoraColors.border,
              color: LivoraColors.forest,
              minHeight: 3,
            ),
        ],
      ),
    );
  }
}
