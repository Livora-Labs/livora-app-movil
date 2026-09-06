import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_theme.dart';

/// Pantalla reusable para escanear códigos QR con la cámara,
/// soporte para validación contextual de formato y overlay animado de error.
class QRScannerView extends StatefulWidget {
  const QRScannerView({super.key, this.validator});

  final bool Function(String code)? validator;

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isInvalidCode = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_isInvalidCode) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        if (widget.validator != null && !widget.validator!(code)) {
          HapticFeedback.vibrate();
          setState(() => _isInvalidCode = true);
          _resetTimer?.cancel();
          _resetTimer = Timer(const Duration(milliseconds: 2000), () {
            if (mounted) {
              setState(() => _isInvalidCode = false);
            }
          });
          return;
        }
        _controller.stop();
        Navigator.pop(context, code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const errorColor = Color(0xFF9E2A2B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código QR'),
        backgroundColor: LivoraColors.deep,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error, child) {
              return Container(
                color: LivoraColors.deep,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudo acceder a la cámara',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      error.errorDetails?.message ??
                          'Verifica que la app tenga permisos de cámara en los ajustes de tu dispositivo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              );
            },
            onDetect: _handleDetect,
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: _isInvalidCode
                      ? errorColor.withValues(alpha: 0.22)
                      : Colors.transparent,
                  border: Border.all(
                    color: _isInvalidCode ? errorColor : LivoraColors.green,
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _isInvalidCode
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: errorColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                              child: const Text(
                                'Código QR no válido. Por favor, encuadra el código correcto.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Text(
              _isInvalidCode
                  ? 'Reintentando lectura...'
                  : 'Apunta al código QR para escanear',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isInvalidCode ? const Color(0xFFFFD166) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                shadows: const [
                  Shadow(offset: Offset(1, 1), blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
