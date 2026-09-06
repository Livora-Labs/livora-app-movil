import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../core/legal_texts.dart';
import '../../core/stellar.dart';
import '../../services/livora_api.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../acopio/center_auctions_screen.dart';
import '../acopio/center_prices_screen.dart';
import '../auth/login_screen.dart';
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
  
  bool _refreshing = false;
  bool _updatingProfile = false;
  bool _fetchingGps = false;
  bool _gpsCaptured = false;
  bool _savingMarketing = false;

  // Password fields
  final _passwordFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _updatingPassword = false;

  @override
  void initState() {
    super.initState();
    debugPrint('>>> [ProfileScreen] initState called!');
    final user = context.read<SessionController>().user;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
      _latitude = user.latitude;
      _longitude = user.longitude;
      _marketingAccepted = user.marketingAccepted;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
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
    if (!mounted) return;
    setState(() => _refreshing = true);
    try {
      final api = context.read<LivoraApi>();
      final raw = await api.client.get('/users/me');
      if (raw is Map<String, dynamic> && mounted) {
        setState(() {
          if (raw['name'] != null && (raw['name'] as String).isNotEmpty) {
            _nameController.text = raw['name'] as String;
          }
          if (raw['phone'] != null && (raw['phone'] as String).isNotEmpty) {
            _phoneController.text = raw['phone'] as String;
          }
          if (raw['address'] != null && (raw['address'] as String).isNotEmpty) {
            _addressController.text = raw['address'] as String;
          }
          if (raw['latitude'] != null) {
            _latitude = (raw['latitude'] as num?)?.toDouble();
          }
          if (raw['longitude'] != null) {
            _longitude = (raw['longitude'] as num?)?.toDouble();
          }
          if (raw['marketingAccepted'] != null) {
            _marketingAccepted = raw['marketingAccepted'] as bool;
          }
          _termsVersion = raw['termsVersion'] as String? ?? '2.0.0';
          _privacyVersion = raw['privacyVersion'] as String? ?? '2.0.0';
        });
      }
    } catch (_) {
      // Mantiene datos locales de sesión
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final api = context.read<LivoraApi>();
    await HapticFeedback.lightImpact();
    setState(() => _updatingProfile = true);
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
    setState(() {
      _fetchingGps = true;
      _gpsCaptured = false;
    });
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          showAppSnack(context, 'No se pudo obtener la geolocalización GPS', error: true);
        }
        return;
      }
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _gpsCaptured = true;
        });
        showAppSnack(context, 'Ubicación GPS capturada con éxito');
        HapticFeedback.lightImpact();

        if (_addressController.text.trim().isEmpty) {
          final addr = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
          if (addr != null && mounted) {
            setState(() {
              _addressController.text = addr;
            });
          }
        }
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  Future<void> _autoSaveMarketing(bool val) async {
    final api = context.read<LivoraApi>();
    setState(() {
      _marketingAccepted = val;
      _savingMarketing = true;
    });
    HapticFeedback.selectionClick();
    try {
      await api.updateProfile(marketingAccepted: val);
      if (mounted) {
        showAppSnack(
          context,
          val
              ? 'Preferencia guardada: Autorizas avisos y promociones comerciales'
              : 'Preferencia guardada: No recibirás publicidad comercial',
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'No se pudo guardar la preferencia de publicidad', error: true);
      }
    } finally {
      if (mounted) setState(() => _savingMarketing = false);
    }
  }

  void _showLegalDocumentSheet(String title, String content, String version) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: LivoraColors.deep,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Versión $version · República del Perú',
                              style: const TextStyle(
                                fontSize: 12,
                                color: LivoraColors.slate,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: SelectableText(
                        content,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: LivoraColors.deep,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: LivoraColors.forest,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) return;

    final passwordController = TextEditingController();
    bool verifying = false;
    String? errorMessage;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
              title: const Text('Eliminar cuenta definitivamente', textAlign: TextAlign.center),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Esta acción es IRREVERSIBLE bajo el marco de la Ley N.° 29733 (Derechos ARCO).\n\n'
                      'Se destruirá permanentemente la clave privada de tu billetera Stellar y se anonimizarán '
                      'tus datos personales y registros en la plataforma.',
                      style: TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Por seguridad, ingresa tu contraseña actual para confirmar tu identidad:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LivoraColors.deep),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        border: const OutlineInputBorder(),
                        errorText: errorMessage,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: verifying ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8C3A3A)),
                  onPressed: verifying
                      ? null
                      : () async {
                          final pwd = passwordController.text;
                          if (pwd.isEmpty) {
                            setDialogState(() => errorMessage = 'Ingresa tu contraseña');
                            return;
                          }
                          setDialogState(() {
                            verifying = true;
                            errorMessage = null;
                          });
                          try {
                            final api = context.read<LivoraApi>();
                            await api.client.post(
                              '/auth/login',
                              body: {'email': user.email, 'password': pwd},
                            );
                            if (context.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (_) {
                            setDialogState(() {
                              verifying = false;
                              errorMessage = 'Contraseña incorrecta';
                            });
                          }
                        },
                  child: verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirmar eliminación'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await session.deleteAccount();
      if (mounted) {
        showAppSnack(context, 'Tu cuenta fue anonimizada y eliminada conforme a ley');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (err) {
      if (mounted) {
        showAppSnack(context, 'Error eliminando la cuenta: $err', error: true);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Estás seguro de que deseas salir de tu cuenta de Livora?',
      confirmLabel: 'Cerrar sesión',
    );
    if (!confirmed || !mounted) return;

    final session = context.read<SessionController>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    debugPrint('>>> [ProfileScreen] build called! user: ${user?.email}, refreshing: $_refreshing');
    
    if (user == null) {
      debugPrint('>>> [ProfileScreen] user is NULL!');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        bottom: _refreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: LivoraColors.forest,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.verified, color: LivoraColors.forest, size: 20),
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
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: _fetchingGps ? null : _geolocalizar,
                                  icon: _fetchingGps
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: LivoraColors.forest,
                                          ),
                                        )
                                      : Icon(
                                          _gpsCaptured ? Icons.check_circle : Icons.gps_fixed,
                                          size: 16,
                                          color: _gpsCaptured ? LivoraColors.green : null,
                                        ),
                                  label: Text(
                                    _fetchingGps
                                        ? 'Obteniendo GPS…'
                                        : _gpsCaptured
                                            ? 'GPS Actualizado'
                                            : 'Capturar GPS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _gpsCaptured ? FontWeight.bold : FontWeight.normal,
                                      color: _gpsCaptured ? LivoraColors.green : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (_latitude != null && _longitude != null)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 14,
                                          color: LivoraColors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _addressController.text.trim().isNotEmpty
                                                ? 'Ubicación vinculada a tu dirección'
                                                : 'Ubicación GPS sincronizada',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: LivoraColors.green,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: LivoraColors.forest,
                                minimumSize: const Size(double.infinity, 44),
                              ),
                              onPressed: _updatingProfile ? null : _saveProfile,
                              child: _updatingProfile
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Guardar Perfil'),
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
                        children: [
                          const Text(
                            'Billetera Digital Livora',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: LivoraColors.deep),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Las transacciones son irreversibles y custodiadas de forma delegada por la plataforma.',
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
                                  tooltip: 'Copiar clave pública',
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  onPressed: () async {
                                    if (user.walletAddress != null) {
                                      await HapticFeedback.lightImpact();
                                      await Clipboard.setData(ClipboardData(text: user.walletAddress!));
                                      if (context.mounted) {
                                        showAppSnack(context, 'Dirección pública copiada al portapapeles');
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (user.walletAddress != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => Stellar.openAccountInExplorer(user.walletAddress),
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
                  if (user.role == Roles.centroAcopio) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Gestión Comercial (Centro de Acopio)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: LivoraColors.deep,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Administra tus tarifas de compra por kilogramo de material y participa en el mercado de subastas de recojo.',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: LivoraColors.forest.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.price_change_outlined,
                                  color: LivoraColors.forest,
                                  size: 20,
                                ),
                              ),
                              title: const Text(
                                'Configurar mi Tarifario',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Precios por kg y reparto financiero transparente',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) =>
                                        const CenterPricesScreen(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: LivoraColors.gold.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.gavel_rounded,
                                  color: LivoraColors.gold,
                                  size: 20,
                                ),
                              ),
                              title: const Text(
                                'Mercado de Subastas',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Ofertar en solicitudes de recojo en vivo',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) =>
                                        const CenterAuctionsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (user.role == Roles.tienda) ...[
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
                            subtitle: const Text('Mandato de firma Web3 y comercio electrónico', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            trailing: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: LivoraColors.forest),
                              ),
                              onPressed: () => _showLegalDocumentSheet(
                                LegalTexts.termsAndConditionsTitle,
                                LegalTexts.termsAndConditions,
                                _termsVersion,
                              ),
                              icon: const Icon(Icons.description_outlined, size: 14, color: LivoraColors.forest),
                              label: Text(
                                'v$_termsVersion · Ver',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: LivoraColors.forest),
                              ),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Política de Privacidad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Protección de Datos Personales (Ley 29733)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            trailing: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: LivoraColors.forest),
                              ),
                              onPressed: () => _showLegalDocumentSheet(
                                LegalTexts.privacyPolicyTitle,
                                LegalTexts.privacyPolicy,
                                _privacyVersion,
                              ),
                              icon: const Icon(Icons.privacy_tip_outlined, size: 14, color: LivoraColors.forest),
                              label: Text(
                                'v$_privacyVersion · Ver',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: LivoraColors.forest),
                              ),
                            ),
                          ),
                          const Divider(),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: LivoraColors.forest,
                            title: const Text(
                              'Autorizo el envío de publicidad y promociones comerciales de Livora (Ley 29733).',
                              style: TextStyle(fontSize: 12, color: LivoraColors.deep),
                            ),
                            subtitle: _savingMarketing
                                ? const Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 1.8, color: LivoraColors.forest),
                                      ),
                                      SizedBox(width: 6),
                                      Text('Guardando preferencia…', style: TextStyle(fontSize: 11, color: LivoraColors.slate)),
                                    ],
                                  )
                                : const Text(
                                    'Preferencia opcional con guardado automático',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                            value: _marketingAccepted,
                            onChanged: _savingMarketing ? null : (val) => _autoSaveMarketing(val ?? false),
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
                  const SizedBox(height: 20),

                  // Botón Cerrar Sesión
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8C3A3A),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
    );
  }
}
