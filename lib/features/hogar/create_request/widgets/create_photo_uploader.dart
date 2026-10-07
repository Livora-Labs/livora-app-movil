import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/app_theme.dart';

/// Micro-widget para adjuntar o tomar una foto del lote de reciclaje.
class CreatePhotoUploader extends StatelessWidget {
  const CreatePhotoUploader({
    super.key,
    this.photo,
    required this.isUploading,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  final File? photo;
  final bool isUploading;
  final void Function(ImageSource source) onPickPhoto;
  final VoidCallback onRemovePhoto;

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: LivoraColors.forest),
              title: const Text('Tomar fotografía'),
              onTap: () {
                Navigator.pop(ctx);
                onPickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: LivoraColors.forest),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                onPickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          image: DecorationImage(
            image: FileImage(photo!),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            if (isUploading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                onPressed: onRemovePhoto,
              ),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.add_a_photo_outlined, size: 20, color: LivoraColors.forest),
      label: const Text('Adjuntar foto del material (opcional)'),
      onPressed: () => _showSourceSheet(context),
    );
  }
}
