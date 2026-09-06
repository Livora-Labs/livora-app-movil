import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../services/livora_api.dart';
import 'common.dart';

/// Modal interactivo que aloja el WebView seguro para procesar el pago con Niubiz.
///
/// Carga la URL GET /payments/niubiz/checkout-page/:purchaseNumber del backend,
/// intercepta la emisión del transactionToken vía JavaScriptChannel ('NiubizBridge')
/// o URL callback, y ejecuta la confirmación autenticada ante LivoraApi.
class NiubizCheckoutModal extends StatefulWidget {
  const NiubizCheckoutModal({
    super.key,
    required this.purchaseNumber,
    required this.amount,
  });

  final String purchaseNumber;
  final double amount;

  static Future<bool?> show(
    BuildContext context, {
    required String purchaseNumber,
    required double amount,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => NiubizCheckoutModal(
        purchaseNumber: purchaseNumber,
        amount: amount,
      ),
    );
  }

  @override
  State<NiubizCheckoutModal> createState() => _NiubizCheckoutModalState();
}

class _NiubizCheckoutModalState extends State<NiubizCheckoutModal> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _confirming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final baseUrl = context.read<ApiClient>().baseUrl;
    final checkoutUrl = '$baseUrl/payments/niubiz/checkout-page/${widget.purchaseNumber}';

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
            if (mounted) {
              setState(() {
                _loading = false;
                _errorMessage = 'Error de conexión: ${error.description}';
              });
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
        'NiubizBridge',
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
        final transactionToken = data['transactionToken'] as String?;
        if (transactionToken != null && transactionToken.isNotEmpty) {
          _confirmPaymentOnBackend(transactionToken);
        }
      } else if (event == 'error') {
        final msg = data['message'] as String? ?? 'Transacción no autorizada';
        if (mounted) {
          setState(() {
            _errorMessage = msg;
          });
          showAppSnack(context, msg, error: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Error al procesar respuesta de Niubiz', error: true);
      }
    }
  }

  Future<void> _confirmPaymentOnBackend(String transactionToken) async {
    setState(() {
      _confirming = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<LivoraApi>();
      final result = await api.confirmPayment(
        purchaseNumber: widget.purchaseNumber,
        transactionToken: transactionToken,
      );

      if (!mounted) return;

      final tokenAmount = (result['tokenAmount'] ?? widget.amount).toString();

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
            '¡Recarga Exitosa!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            'Se han acreditado $tokenAmount EcoTokens en tu billetera Livora tras tu pago de S/ ${widget.amount.toStringAsFixed(2)} PEN.',
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
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _confirming = false;
          _errorMessage = e.message;
        });
        showAppSnack(context, e.message, error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _confirming = false;
          _errorMessage = 'Fallo inesperado en la confirmación';
        });
        showAppSnack(context, 'Error al confirmar recarga', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final modalHeight = mediaQuery.size.height * 0.88;

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
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pago Seguro Niubiz',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: LivoraColors.ink,
                          ),
                        ),
                        Text(
                          'Total: S/ ${widget.amount.toStringAsFixed(2)} PEN',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),

          // Contenedor principal con WebView y loaders
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 12),
                        Text(
                          'Cargando pasarela bancaria segura...',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                if (_confirming)
                  Container(
                    color: Colors.white.withValues(alpha: 0.92),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            strokeWidth: 3,
                            color: LivoraColors.forest,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Confirmando autorización bancaria...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: LivoraColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Minteando ${widget.amount.toStringAsFixed(2)} EcoTokens en la blockchain...',
                            style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_errorMessage != null && !_confirming)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                            ),
                          ),
                        ],
                      ),
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
