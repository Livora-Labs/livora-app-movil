import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_shimmer.dart';

/// Pantalla de Perfil Comercial para el rol TIENDA.
/// Valida datos fiscales estrictos bajo regulación peruana (RUC 11 dígitos iniciando con 10/20 y CCI de 20 dígitos).
class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _rucController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankAccountController = TextEditingController();

  bool _loading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _rucController.dispose();
    _addressController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final api = context.read<LivoraApi>();
      final profile = await api.getStoreProfile();
      if (profile != null && mounted) {
        _businessNameController.text = profile['businessName']?.toString() ?? '';
        _rucController.text = profile['ruc']?.toString() ?? '';
        _addressController.text = profile['address']?.toString() ?? '';
        _bankAccountController.text = profile['bankAccount']?.toString() ?? '';
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      // Error silencioso al cargar perfil nuevo
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final api = context.read<LivoraApi>();
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _busy = true);

    try {
      await api.updateStoreProfile(
        businessName: _businessNameController.text.trim(),
        ruc: _rucController.text.trim(),
        address: _addressController.text.trim(),
        bankAccount: _bankAccountController.text.trim(),
      );
      if (mounted) {
        showAppSnack(context, 'Perfil comercial guardado con éxito');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Error al guardar el perfil comercial', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Comercial de Tienda'),
      ),
      body: _loading
          ? const LivoraShimmerList(
              itemCount: 4,
              padding: EdgeInsets.fromLTRB(20, 16, 20, 80),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Informativo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LivoraColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: LivoraColors.forest.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.verified_user_outlined, color: LivoraColors.forest, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Datos Fiscales y Bancarios',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: LivoraColors.deep,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Configura tu RUC y cuenta interbancaria (CCI) para recibir tus liquidaciones en moneda nacional (PEN).',
                                  style: TextStyle(fontSize: 12, color: LivoraColors.ink, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Campo Razón Social
                    TextFormField(
                      controller: _businessNameController,
                      decoration: livoraInput(
                        'Razón Social / Nombre Comercial',
                        icon: Icons.store_outlined,
                        hint: 'Mi Tienda S.A.C.',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa la razón social o nombre comercial'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Campo RUC (11 dígitos, inicia con 10 o 20)
                    TextFormField(
                      controller: _rucController,
                      decoration: livoraInput(
                        'RUC (11 dígitos)',
                        icon: Icons.badge_outlined,
                        hint: '20608912345',
                        helper: 'Debe contener exactamente 11 dígitos e iniciar con 10 u 20.',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: kRucInputFormatters,
                      validator: validateRuc,
                    ),
                    const SizedBox(height: 18),

                    // Campo Dirección Comercial
                    TextFormField(
                      controller: _addressController,
                      decoration: livoraInput(
                        'Dirección Comercial',
                        icon: Icons.location_on_outlined,
                        hint: 'Av. Larco 123, Miraflores, Lima',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa la dirección física de la tienda'
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Campo Cuenta Bancaria CCI (exactamente 20 dígitos)
                    TextFormField(
                      controller: _bankAccountController,
                      decoration: livoraInput(
                        'Código de Cuenta Interbancario (CCI)',
                        icon: Icons.account_balance_outlined,
                        hint: '00219100000000000012',
                        helper: 'Debe ser un CCI de exactamente 20 dígitos (no número de cuenta corriente local de 13 dígitos).',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: kCciInputFormatters,
                      validator: validateCci,
                    ),
                    const SizedBox(height: 32),

                    // Botón Principal BusyButton con respuesta háptica
                    BusyButton(
                      label: 'Guardar Configuración Comercial',
                      icon: Icons.save_rounded,
                      busy: _busy,
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
