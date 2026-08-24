import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

/// Verificación de identidad del recolector.
///
/// Sube el documento a `/uploads` (`purpose: kyc`, acepta jpeg/png/pdf) y
/// envía la URL resultante a `POST /collectors/kyc-applications`.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  String? _filePath;
  String? _fileName;
  String? _documentUrl;
  bool _uploading = false;
  bool _sending = false;

  KycApplication? _application;
  String? _loadError;
  bool _loading = true;

  bool get _isPdf => (_fileName ?? '').toLowerCase().endsWith('.pdf');

  /// Solo mostramos el formulario si nunca se envió o si fue rechazada.
  bool get _canSubmit => _application?.canSubmit ?? false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final application = await context.read<LivoraApi>().kycApplication();
      if (mounted) {
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
    setState(() {
      _filePath = path;
      _fileName = name;
      _documentUrl = null;
      _uploading = true;
    });
    try {
      final url = await context.read<LivoraApi>().uploadFile(
        filePath: path,
        purpose: 'kyc',
      );
      if (mounted) setState(() => _documentUrl = url);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _filePath = null;
          _fileName = null;
        });
        showAppSnack(context, error.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _upload(picked.path, picked.name);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final picked = result?.files.single;
    if (picked?.path == null) return;
    await _upload(picked!.path!, picked.name);
  }

  Future<void> _chooseSource() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Fotografiar el documento'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir imagen de la galería'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Adjuntar un PDF'),
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

  Future<void> _submit() async {
    final documentUrl = _documentUrl;
    if (documentUrl == null) return;
    setState(() => _sending = true);
    try {
      await context.read<LivoraApi>().submitKycApplication(documentUrl);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            color: LivoraColors.green,
            size: 40,
          ),
          title: const Text('Solicitud enviada'),
          content: const Text(
            'Un administrador revisará tu documento. Te avisaremos por '
            'notificación cuando quede aprobada.',
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
        setState(() {
          _filePath = null;
          _fileName = null;
          _documentUrl = null;
        });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Verificación de identidad')),
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
                    leading: const Icon(
                      Icons.cloud_off,
                      color: Color(0xFF8C3A3A),
                    ),
                    title: Text(
                      _loadError!,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: TextButton(
                      onPressed: _loadStatus,
                      child: const Text('Reintentar'),
                    ),
                  ),
                )
              else
                _StatusCard(application: _application!),
              if (!_loading && _canSubmit) ...[
                const SizedBox(height: 16),
                const SectionTitle(text: 'Documento'),
                if (_filePath == null)
                  OutlinedButton.icon(
                    onPressed: _chooseSource,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Seleccionar documento'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (!_isPdf)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.file(
                                File(_filePath!),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              if (_uploading)
                                Container(
                                  height: 180,
                                  width: double.infinity,
                                  color: Colors.black.withValues(alpha: 0.45),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ListTile(
                          leading: Icon(
                            _isPdf
                                ? Icons.picture_as_pdf_outlined
                                : Icons.image_outlined,
                            color: LivoraColors.forest,
                          ),
                          title: Text(
                            _fileName ?? 'Documento',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            _uploading
                                ? 'Subiendo…'
                                : _documentUrl != null
                                ? 'Listo para enviar'
                                : 'Sin subir',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            tooltip: 'Cambiar',
                            onPressed: _uploading ? null : _chooseSource,
                            icon: const Icon(Icons.swap_horiz),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                BusyButton(
                  label: _application?.isRejected == true
                      ? 'Reenviar para revisión'
                      : 'Enviar para revisión',
                  icon: Icons.send_rounded,
                  busy: _sending,
                  onPressed: _documentUrl == null || _uploading
                      ? null
                      : _submit,
                ),
                const SizedBox(height: 10),
                Text(
                  'Formatos aceptados: JPG, PNG o PDF, hasta 10 MB.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: LivoraColors.ink.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con el estado actual de la verificación.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.application});

  final KycApplication application;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, message) = switch (application.status) {
      'APPROVED' => (
        Icons.verified_rounded,
        LivoraColors.green,
        'Identidad verificada',
        'Tu documento fue aprobado. Ya operas como recolector verificado.',
      ),
      'PENDING' => (
        Icons.hourglass_top_rounded,
        const Color(0xFFB7791F),
        'En revisión',
        'Un administrador está revisando tu documento. Te avisaremos por '
            'notificación cuando haya respuesta.',
      ),
      'REJECTED' => (
        Icons.cancel_rounded,
        const Color(0xFF8C3A3A),
        'Documento rechazado',
        'No pudimos validar el documento que enviaste. Sube uno nuevo, '
            'legible y con los datos visibles.',
      ),
      _ => (
        Icons.badge_outlined,
        LivoraColors.forest,
        'Sin verificar',
        'Sube una foto o un PDF de tu documento de identidad. Verificarte '
            'da más confianza a los hogares y es requisito para operar.',
      ),
    };

    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: LivoraColors.ink,
                    ),
                  ),
                  if (application.updatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Actualizado: ${fmtDate(application.updatedAt)}',
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
