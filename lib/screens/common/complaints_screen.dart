// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../data/repositories/complaints_repository.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _formKey = GlobalKey<FormState>();

  String _documentType = 'DNI';
  final _docNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isMinor = false;
  final _repNameController = TextEditingController();
  final _repDocController = TextEditingController();

  String _goodType = 'SERVICIO';
  final _amountController = TextEditingController();
  final _goodDescController = TextEditingController();

  String _claimType = 'RECLAMO';
  final _claimDetailController = TextEditingController();
  final _consumerReqController = TextEditingController();

  bool _affidavitConsent = false;
  bool _submitting = false;

  Map<String, dynamic>? _successResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<SessionController>().user;
      if (user != null) {
        if (_fullNameController.text.isEmpty && user.name != null) {
          _fullNameController.text = user.name!;
        }
        if (_emailController.text.isEmpty) {
          _emailController.text = user.email;
        }
        if (_phoneController.text.isEmpty && user.phone != null) {
          _phoneController.text = user.phone!;
        }
        if (_addressController.text.isEmpty && user.address != null) {
          _addressController.text = user.address!;
        }
      }
    });
  }

  @override
  void dispose() {
    _docNumberController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _repNameController.dispose();
    _repDocController.dispose();
    _amountController.dispose();
    _goodDescController.dispose();
    _claimDetailController.dispose();
    _consumerReqController.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) {
      showAppSnack(context, 'Por favor revisa los campos requeridos', error: true);
      return;
    }
    if (!_affidavitConsent) {
      showAppSnack(
        context,
        'Debes aceptar la declaración jurada para registrar la reclamación',
        error: true,
      );
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ComplaintsRepository(api: context.read<LivoraApi>());
      final amountVal = _amountController.text.trim().isNotEmpty
          ? double.tryParse(_amountController.text.trim())
          : null;

      final res = await repo.submitComplaint(
        documentType: _documentType,
        documentNumber: _docNumberController.text.trim(),
        fullName: _fullNameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        isMinor: _isMinor,
        representativeName: _isMinor ? _repNameController.text.trim() : null,
        representativeDoc: _isMinor ? _repDocController.text.trim() : null,
        goodType: _goodType,
        goodDescription: _goodDescController.text.trim(),
        amount: amountVal,
        claimType: _claimType,
        claimDetail: _claimDetailController.text.trim(),
        consumerRequest: _consumerReqController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _successResult = res;
        });
        showAppSnack(context, 'Reclamación registrada exitosamente');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnack(context, e.message, error: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo registrar la reclamación. Por favor reintenta.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_successResult != null) {
      return _buildSuccessView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Libro de Reclamaciones',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Consultar Estado de Reclamo',
            icon: const Icon(Icons.track_changes_rounded),
            onPressed: _showTrackComplaintDialog,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // Banner de Identificación y Ley
            Card(
              color: LivoraColors.forest.withValues(alpha: 0.08),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: LivoraColors.forest.withValues(alpha: 0.25),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: LivoraColors.forest, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Livora S.A.C. · RUC 20608912345',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: LivoraColors.forest,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Conforme al Código de Protección y Defensa del Consumidor (Ley N° 29571) y Ley N° 32495. Plazo legal máximo de respuesta: 15 días hábiles.',
                      style: TextStyle(fontSize: 11.5, color: LivoraColors.slate, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECCIÓN 1: Consumidor Reclamante
            _buildSectionHeader('1. Identificación del Consumidor'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _documentType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Documento *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'DNI', child: Text('DNI')),
                        DropdownMenuItem(value: 'CE', child: Text('Carnet de Extranjería (CE)')),
                        DropdownMenuItem(value: 'PASAPORTE', child: Text('Pasaporte')),
                        DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _documentType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _docNumberController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Número de Documento *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombres y Apellidos Completos *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Domicilio Completo *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono o Celular *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico (Para copia PDF) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: LivoraColors.forest,
                      title: const Text(
                        'El reclamante es menor de edad',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _isMinor,
                      onChanged: (val) => setState(() => _isMinor = val ?? false),
                    ),
                    if (_isMinor) ...[
                      const Divider(height: 16),
                      TextFormField(
                        controller: _repNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Padre, Madre o Apoderado *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            _isMinor && (v == null || v.trim().isEmpty) ? 'Requerido para menores' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _repDocController,
                        decoration: const InputDecoration(
                          labelText: 'Documento del Apoderado (Opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECCIÓN 2: Bien Contratado
            _buildSectionHeader('2. Identificación del Bien Contratado'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo de Bien *', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _goodType = 'SERVICIO'),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'SERVICIO',
                                  groupValue: _goodType,
                                  activeColor: LivoraColors.forest,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _goodType = v);
                                  },
                                ),
                                const Text('Servicio', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _goodType = 'PRODUCTO'),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'PRODUCTO',
                                  groupValue: _goodType,
                                  activeColor: LivoraColors.forest,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _goodType = v);
                                  },
                                ),
                                const Text('Producto', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto Reclamado (Opcional - S/. o LIVO)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _goodDescController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción del Producto o Servicio *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECCIÓN 3: Detalle de la Reclamación
            _buildSectionHeader('3. Detalle de la Reclamación'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo de Reclamación *', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _claimType = 'RECLAMO'),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'RECLAMO',
                                  groupValue: _claimType,
                                  activeColor: LivoraColors.forest,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _claimType = v);
                                  },
                                ),
                                const Expanded(
                                  child: Text('Reclamo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _claimType = 'QUEJA'),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'QUEJA',
                                  groupValue: _claimType,
                                  activeColor: LivoraColors.amber,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _claimType = v);
                                  },
                                ),
                                const Expanded(
                                  child: Text('Queja', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _claimDetailController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Detalle de los Hechos *',
                        hintText: 'Describe de manera clara lo ocurrido...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _consumerReqController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Pedido Concreto del Consumidor *',
                        hintText: 'Indica la solución requerida...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SECCIÓN 4: Declaración Jurada
            Card(
              color: Colors.amber.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: LivoraColors.forest,
                  title: const Text(
                    'Declaración Jurada: Declaro bajo fe de juramento que la información y hechos expresados son verídicos. Entiendo que se enviará una copia en PDF al correo indicado y Livora responderá en un plazo máximo de 15 días hábiles conforme a Ley N° 29571.',
                    style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.brown),
                  ),
                  value: _affidavitConsent,
                  onChanged: (val) => setState(() => _affidavitConsent = val ?? false),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón de Envío
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submitting ? null : _submitComplaint,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _submitting ? 'Registrando Reclamación…' : 'Enviar Reclamación Virtual',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _showTrackComplaintDialog() async {
    final correlativeCtrl = TextEditingController();
    final docNumberCtrl = TextEditingController();
    final trackFormKey = GlobalKey<FormState>();
    bool tracking = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.track_changes_rounded, color: LivoraColors.forest),
                SizedBox(width: 8),
                Text('Seguimiento de Reclamo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Form(
              key: trackFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresa tu número correlativo y documento de identidad para verificar el estado de atención:',
                    style: TextStyle(fontSize: 12.5, color: LivoraColors.slate),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: correlativeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número Correlativo *',
                      hintText: 'Ej. R-00001-2026 o Q-00001-2026',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: docNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número de Documento (DNI/CE/RUC) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: tracking ? null : () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
                onPressed: tracking
                    ? null
                    : () async {
                        if (!trackFormKey.currentState!.validate()) return;
                        setDialogState(() => tracking = true);
                        try {
                          final api = context.read<LivoraApi>();
                          final res = await api.trackComplaint(
                            correlativeNumber: correlativeCtrl.text.trim(),
                            documentNumber: docNumberCtrl.text.trim(),
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _showTrackingResultDialog(res);
                          }
                        } catch (e) {
                          setDialogState(() => tracking = false);
                          if (ctx.mounted) {
                            showAppSnack(ctx, 'No se encontró la reclamación o los datos no coinciden', error: true);
                          }
                        }
                      },
                child: tracking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Consultar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTrackingResultDialog(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'RECEIVED';
    final correlative = data['correlativeNumber'] as String? ?? '';
    final createdAt = data['createdAt'] != null ? DateTime.tryParse(data['createdAt'].toString()) : null;
    final responseText = data['responseText'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estado de la Reclamación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'RESOLVED' ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: status == 'RESOLVED' ? Colors.green : Colors.amber),
              ),
              child: Text(
                'ESTADO: $status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: status == 'RESOLVED' ? Colors.green.shade800 : Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Correlativo: $correlative', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text('Fecha de registro: ${createdAt.day}/${createdAt.month}/${createdAt.year}'),
            ],
            const SizedBox(height: 10),
            if (responseText != null && responseText.isNotEmpty) ...[
              const Text('Respuesta oficial:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(responseText, style: const TextStyle(fontSize: 13)),
            ] else ...[
              const Text(
                'Tu reclamación se encuentra en trámite. Conforme a ley, el plazo de respuesta es de hasta 15 días hábiles.',
                style: TextStyle(fontSize: 12, color: LivoraColors.slate),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LivoraColors.forest),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: LivoraColors.deep,
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final correlative = _successResult?['correlativeNumber'] ?? 'Q-XXXXX-YYYY';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Constancia de Reclamación'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: LivoraColors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: LivoraColors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '¡Reclamación Registrada!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: LivoraColors.deep,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tu hoja de reclamación ha sido procesada de acuerdo a ley.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Tarjeta de Correlativo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: LivoraColors.forest.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'NÚMERO CORRELATIVO OFICIAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: LivoraColors.forest,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      correlative,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: LivoraColors.forest,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hemos enviado una copia fiel en formato PDF a ${_emailController.text.trim()}. Conserva este correlativo para consultas y seguimiento.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: LivoraColors.deep),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 0,
                color: Colors.grey.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: LivoraColors.slate, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Conforme a la Ley N° 29571, Livora cuenta con un plazo máximo de 15 días hábiles no prorrogables para brindar una respuesta formal.',
                          style: TextStyle(fontSize: 11.5, color: LivoraColors.slate, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: LivoraColors.forest,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver al Perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
