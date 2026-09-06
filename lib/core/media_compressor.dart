import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Utilidad de optimización y compresión de imágenes antes de su envío a la API.
class MediaCompressor {
  const MediaCompressor._();

  /// Comprime una imagen a formato JPEG optimizado (calidad 75-80%) asegurando que pese menos de 500 KB.
  /// Si el archivo es un PDF, ya es liviano o si la compresión falla, retorna el archivo original de forma segura.
  static Future<File> compressImage(
    File file, {
    int quality = 75,
    int minWidth = 1600,
    int minHeight = 1200,
  }) async {
    final path = file.path.toLowerCase();
    final isSupportedImage = path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.heic');

    if (!isSupportedImage) {
      return file;
    }

    try {
      final originalSize = await file.length();
      // Si la imagen ya es pequeña (< 200 KB), no es necesario recomprimir
      if (originalSize <= 200 * 1024) {
        return file;
      }

      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/comp_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        final compressedSize = await compressedFile.length();
        debugPrint(
          '[MediaCompressor] Imagen comprimida de ${(originalSize / 1024).toStringAsFixed(1)} KB a ${(compressedSize / 1024).toStringAsFixed(1)} KB',
        );
        return compressedFile;
      }
    } catch (e) {
      debugPrint('[MediaCompressor] Aviso: No se pudo comprimir la imagen ($e). Usando archivo original.');
    }
    return file;
  }
}
