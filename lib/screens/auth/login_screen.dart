import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_logo.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<SessionController>().login(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Ocurrió un error inesperado', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _tapCount++;
                            if (_tapCount >= 5) {
                              _tapCount = 0;
                              showServerSettingsDialog(context);
                            }
                          });
                        },
                        child: const LivoraWordmark(),
                      ),
                      const SizedBox(height: 32),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Bienvenido de nuevo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: LivoraColors.deep,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: livoraInput(
                                    'Correo electrónico',
                                    icon: Icons.mail_outline,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  validator: (value) =>
                                      value == null || !value.contains('@')
                                          ? 'Ingresa un correo válido'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: livoraInput(
                                    'Contraseña',
                                    icon: Icons.lock_outline,
                                    suffix: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscure,
                                  onFieldSubmitted: (_) => _login(),
                                  validator: (value) =>
                                      value == null || value.length < 8
                                          ? 'Mínimo 8 caracteres'
                                          : null,
                                ),
                                const SizedBox(height: 20),
                                BusyButton(
                                  label: 'Iniciar sesión',
                                  busy: _busy,
                                  onPressed: _login,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: const Text('¿No tienes cuenta? Regístrate'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para configurar la URL del backend (útil en emulador vs. equipo).
Future<void> showServerSettingsDialog(BuildContext context) async {
  final api = context.read<ApiClient>();
  final controller = TextEditingController(text: api.baseUrl);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Servidor de la API'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: livoraInput(
              'URL base',
              hint: ApiClient.defaultBaseUrl,
              helper:
                  'Servidor de conexión de la API de Livora. Por defecto: ${ApiClient.defaultBaseUrl}',
            ),
            keyboardType: TextInputType.url,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () async {
            await api.setBaseUrl(controller.text);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
