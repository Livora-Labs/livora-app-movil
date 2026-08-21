import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  int _cooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown > 0) {
        setState(() => _cooldown--);
      } else {
        _cooldownTimer?.cancel();
      }
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await context.read<SessionController>().verifyEmail(
            email: widget.email,
            code: _codeController.text.trim(),
          );
      if (mounted) {
        showAppSnack(context, '¡Cuenta verificada exitosamente!');
        // Navegar a la pantalla de inicio limpia quitando la pila
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Ocurrió un error inesperado al verificar el OTP', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    setState(() => _busy = true);

    try {
      await context.read<SessionController>().resendOtp(email: widget.email);
      _startCooldown();
      if (mounted) showAppSnack(context, 'Se ha enviado un nuevo código de verificación.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al reenviar el código OTP', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar Cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Código de Verificación',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: .0 == 0.0 ? TextAlign.center : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hemos enviado un código OTP de 6 dígitos a ${widget.email}. Ingrésalo a continuación para activar tu cuenta.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _codeController,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 12,
                      ),
                      decoration: livoraInput(
                        'Código OTP',
                        hint: '000000',
                      ).copyWith(counterText: ''),
                      validator: (value) {
                        if (value == null || value.trim().length != 6) {
                          return 'Ingresa los 6 dígitos del código';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Solo se permiten números';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _busy
                        ? const Center(child: CircularProgressIndicator())
                        : FilledButton(
                            onPressed: _verify,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: const Text('Verificar Código'),
                          ),
                    const SizedBox(height: 24),
                    Center(
                      child: _cooldown > 0
                          ? Text(
                              'Reenviar código en ${_cooldown}s',
                              style: const TextStyle(color: Colors.grey),
                            )
                          : TextButton.icon(
                              onPressed: _resend,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reenviar Código de Verificación'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
