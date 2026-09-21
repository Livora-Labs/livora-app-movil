import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import 'common.dart';

/// Modal interactivo que aloja el WebView seguro para procesar el pago con Izipay (Krypton V4).
///
/// Carga la URL GET /payments/izipay/checkout-page/:orderId del backend,
/// intercepta la finalización exitosa vía JavaScriptChannel ('IzipayBridge')
/// o URL callback ('livora://payment-callback'), notificando el éxito a la pantalla invocadora.
class IzipayCheckoutModal extends StatefulWidget {
  const IzipayCheckoutModal({
    super.key,
    required this.orderId,
    required this.amount,
  });

  final String orderId;
  final double amount;

  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    required double amount,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => IzipayCheckoutModal(
        orderId: orderId,
        amount: amount,
      ),
    );
  }

  @override
  State<IzipayCheckoutModal> createState() => _IzipayCheckoutModalState();
}

class _IzipayCheckoutModalState extends State<IzipayCheckoutModal> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final baseUrl = context.read<ApiClient>().baseUrl;
    final checkoutUrl = '$baseUrl/payments/izipay/checkout-page/${widget.orderId}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _errorMessage = 'Error de conexión: ${error.description}';
                });
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('livora://payment-callback')) {
              _handleUriCallback(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'IzipayBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(checkoutUrl));
  }

  void _handleUriCallback(String url) {
    try {
      final uri = Uri.parse(url);
      final rawData = uri.queryParameters['data'];
      if (rawData != null) {
        _handleBridgeMessage(rawData);
      }
    } catch (_) {}
  }

  void _handleBridgeMessage(String rawJson) {
    try {
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      final event = data['event'] as String?;

      if (event == 'success') {
        _handlePaymentSuccess();
      } else if (event == 'error') {
        final msg = data['message'] as String? ?? 'Transacción no completada';
        if (mounted) {
          setState(() {
            _errorMessage = msg;
          });
          showAppSnack(context, msg, error: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Error al procesar respuesta de la pasarela', error: true);
      }
    }
  }

  Future<void> _handlePaymentSuccess() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: LivoraColors.green,
          size: 48,
        ),
        title: const Text(
          'Pago procesado exitosamente',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Se ha registrado tu pago de S/ ${widget.amount.toStringAsFixed(2)} PEN.\nTus LIVOs se reflejarán en tu saldo disponible en unos instantes.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final modalHeight = mediaQuery.size.height * 0.90;

    return Container(
      height: modalHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header del modal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: LivoraColors.forest,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pago Seguro Izipay',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: LivoraColors.ink,
                          ),
                        ),
                        Text(
                          'Orden: ${widget.orderId} · S/ ${widget.amount.toStringAsFixed(2)} PEN',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LivoraColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: LivoraColors.slate),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, false);
                  },
                ),
              ],
            ),
          ),

          // Banner de error si ocurre
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Cuerpo: WebView con indicador de carga
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(LivoraColors.forest),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Cargando pasarela de pago segura...',
                          style: TextStyle(
                            fontSize: 13,
                            color: LivoraColors.slate,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
