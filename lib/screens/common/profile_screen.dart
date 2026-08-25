import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../core/stellar.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../tienda/store_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  double? _latitude;
  double? _longitude;
  bool _marketingAccepted = false;
  
  String _termsVersion = '2.0.0';
  String _privacyVersion = '2.0.0';
  
  bool _loading = true;
  bool _updatingProfile = false;

  // Password fields
  final _passwordFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _updatingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final api = context.read<LivoraApi>();
    try {
      final data = await api.client.get('/users/me') as Map<String, dynamic>;
      setState(() {
        _nameController.text = data['name'] as String? ?? '';
        _phoneController.text = data['phone'] as String? ?? '';
        _addressController.text = data['address'] as String? ?? '';
        _latitude = data['latitude'] == null ? null : (data['latitude'] as num).toDouble();
        _longitude = data['longitude'] == null ? null : (data['longitude'] as num).toDouble();
        _marketingAccepted = data['marketingAccepted'] as bool? ?? false;
        _termsVersion = data['termsVersion'] as String? ?? '2.0.0';
        _privacyVersion = data['privacyVersion'] as String? ?? '2.0.0';
        _loading = false;
      });
    } on ApiException catch (err) {
      if (mounted) {
        showAppSnack(context, err.message, error: true);
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _updatingProfile = true);
    final api = context.read<LivoraApi>();
    try {
      await api.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        marketingAccepted: _marketingAccepted,
      );
      if (mounted) {
        showAppSnack(context, 'Perfil actualizado con éxito');
        _loadProfile();
      }
    } on ApiException catch (err) {
      if (mounted) {
        showAppSnack(context, err.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _updatingProfile = false);
      }
    }
  }

  Future<void> _geolocalizar() async {
    showAppSnack(context, 'Obteniendo GPS...');
    final pos = await LocationService.getCurrentPosition();
    if (pos == null) {
      if (mounted) {
        showAppSnack(context, 'No se pudo obtener la geolocalización', error: true);
      }
      return;
    }
    setState(() {
      _latitude = pos.latitude;
      _longitude = pos.longitude;
    });
    if (mounted) {
      showAppSnack(context, 'Coordenadas capturadas con éxito');
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    
    if (newPassword != confirmPassword) {
      showAppSnack(context, 'Las contraseñas no coinciden', error: true);
      return;
    }

    final passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>_+\-=\[\]\\/])[A-Za-z\d!@#$%^&*(),.?":{}|<>_+\-=\[\]\\/]{8,}$');
    if (!passwordRegex.hasMatch(newPassword)) {
      showAppSnack(context, 'La contraseña debe incluir mayúsculas, minúsculas, números y caracteres especiales', error: true);
      return;
    }

    setState(() => _updatingPassword = true);
    final api = context.read<LivoraApi>();
    try {
      await api.changePassword(newPassword);
      if (mounted) {
        showAppSnack(context, 'Contraseña cambiada con éxito');
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } on ApiException catch (err) {
      if (mounted) {
        showAppSnack(context, err.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _updatingPassword = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmationTextController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar mi cuenta', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta acción es IRREVERSIBLE. Se destruirá la clave privada de tu billetera Stellar '
                'y se anonimizarán tus datos personales de acuerdo a la Ley N.° 29733 (ARCO).\n\n'
                'Escribe a continuación exactamente para confirmar:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'ELIMINAR MI CUENTA',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.red),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmationTextController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: 'Escribe aquí...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (confirmationTextController.text.trim() == 'ELIMINAR MI CUENTA') {
                  Navigator.pop(dialogContext, true);
                } else {
                  showAppSnack(dialogContext, 'Texto de confirmación inválido', error: true);
                }
              },
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final session = context.read<SessionController>();
    final api = context.read<LivoraApi>();
    
    try {
      await api.deleteAccount();
      await session.logout();
      if (mounted) {
        showAppSnack(context, 'Tu cuenta fue anonimizada y eliminada');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (err) {
      if (mounted) {
        showAppSnack(context, err.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Datos Personales
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Datos Personales',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre Completo',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: user.email,
                              readOnly: true,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Correo Electrónico',
                                border: const OutlineInputBorder(),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    label: const Text('Verificado', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                                    backgroundColor: LivoraColors.green,
                                    padding: EdgeInsets.zero,
                                    side: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono / Celular',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Dirección de Recojo',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _geolocalizar,
                                  icon: const Icon(Icons.gps_fixed, size: 16),
                                  label: const Text('Capturar GPS', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 10),
                                if (_latitude != null && _longitude != null)
                                  Expanded(
                                    child: Text(
                                      'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _updatingProfile ? null : _saveProfile,
                              child: Text(_updatingProfile ? 'Guardando...' : 'Guardar Perfil'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Billetera Stellar
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                          const Text(
                            'Billetera Digital Livora',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Las transacciones son irreversibles y custodias de forma delegada por la plataforma.',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: LivoraColors.paper,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    user.walletAddress ?? 'No generada',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  onPressed: () {
                                    if (user.walletAddress != null) {
                                      Clipboard.setData(ClipboardData(text: user.walletAddress!));
                                      showAppSnack(context, 'Copiado al portapapeles');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (user.walletAddress != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final url = Stellar.accountUrl(user.walletAddress!);
                                await Stellar.openInExplorer(url);
                              },
                              icon: const Icon(Icons.receipt_long_outlined, size: 16),
                              label: const Text('Ver comprobante digital'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Seguridad (Contraseña)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _passwordFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Seguridad',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Nueva Contraseña',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.length < 8 ? 'Mínimo 8 caracteres' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirmar Contraseña',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _updatingPassword ? null : _changePassword,
                              child: Text(_updatingPassword ? 'Cambiando...' : 'Cambiar Contraseña'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (user.role == Roles.almacen) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Perfil Comercial (Tienda)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Configura tu RUC, razón social, dirección y cuenta bancaria interbancaria (CCI) para recibir transferencias de moneda local por tus EcoTokens liquidadores.',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) => const StoreProfileScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Configurar Datos Comerciales'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Consentimientos
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Consentimientos y Privacidad',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Términos y Condiciones', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            trailing: Text('Aceptado v$_termsVersion', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Política de Privacidad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            trailing: Text('Aceptado v$_privacyVersion', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                          const Divider(),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Autorizo el envío de publicidad y promociones comerciales de Livora (Ley 29733).',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            value: _marketingAccepted,
                            onChanged: (val) {
                              setState(() {
                                _marketingAccepted = val ?? false;
                              });
                            },
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
                            onPressed: _updatingProfile ? null : _saveProfile,
                            icon: const Icon(Icons.save_outlined, size: 16),
                            label: const Text('Guardar Preferencias de Privacidad'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Libro de Reclamaciones
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Ayuda y Soporte',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.menu_book_outlined, color: LivoraColors.amber),
                            title: const Text(
                              'Libro de Reclamaciones',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Hoja de reclamación virtual conforme a ley',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final api = context.read<LivoraApi>();
                              final webBaseUrl = api.client.baseUrl.replaceAll('/api', '');
                              final url = Uri.parse('$webBaseUrl/libro-de-reclamaciones');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  showAppSnack(context, 'No se pudo abrir el Libro de Reclamaciones', error: true);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Zona de Peligro
                  Card(
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.red.shade200, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Zona de Peligro',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'La eliminación de la cuenta es permanente y anonimiza tus datos de acuerdo con la Ley N.° 29733 (ARCO).',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _confirmDeleteAccount,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Eliminar cuenta definitivamente'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
