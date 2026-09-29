import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/livora_api.dart';
import '../../../widgets/common.dart';

enum IncidentType {
  noShow,
  rejectOnSite,
  abandonRoute,
}

/// Diálogo profesional para la resolución de incidencias en ruta o en puerta.
/// Permite al recolector liberar una orden sin quedar atrapado, invocando
/// los endpoints del backend: /no-show, /reject-on-site o /abandon.
class CollectorIncidentDialog extends StatefulWidget {
  const CollectorIncidentDialog({
    super.key,
    required this.request,
  });

  final CollectionRequest request;

  static Future<bool?> show(
    BuildContext context, {
    required CollectionRequest request,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectorIncidentDialog(request: request),
    );
  }

  @override
  State<CollectorIncidentDialog> createState() => _CollectorIncidentDialogState();
}

class _CollectorIncidentDialogState extends State<CollectorIncidentDialog> {
  IncidentType _selectedType = IncidentType.noShow;
  final _reasonCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final api = context.read<LivoraApi>();
    final reason = _reasonCtrl.text.trim();

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();

    try {
      switch (_selectedType) {
        case IncidentType.noShow:
          await api.reportNoShow(widget.request.id);
          if (mounted) {
            showAppSnack(
              context,
              'Incidencia registrada: Hogar ausente. La orden ha sido liberada.',
            );
          }
          break;

        case IncidentType.rejectOnSite:
          if (reason.isEmpty) {
            setState(() => _busy = false);
            showAppSnack(
              context,
              'Por favor ingresa el motivo del rechazo del material.',
              error: true,
            );
            return;
          }
          await api.rejectOnSite(widget.request.id, reason);
          if (mounted) {
            showAppSnack(
              context,
              'Material rechazado por no conformidad. Orden finalizada.',
            );
          }
          break;

        case IncidentType.abandonRoute:
          final note = reason.isNotEmpty ? reason : 'Avería o emergencia en trayecto';
          await api.abandonCollectionRequest(widget.request.id, reason: note);
          if (mounted) {
            showAppSnack(
              context,
              'Ruta cancelada por emergencia. La orden volverá al radar.',
            );
          }
          break;
      }

      if (mounted) {
        Navigator.pop(context, true); // Retorna true para salir de la consola vehicular
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, 'No se pudo reportar la incidencia. Reintenta.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.report_problem_rounded,
                  color: Colors.amber.shade800,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reportar Problema en Ruta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LivoraColors.deep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona el motivo para cancelar o reasignar la orden sin dejar trabada tu jornada:',
            style: TextStyle(
              fontSize: 12.5,
              color: LivoraColors.ink.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),

          // Opción 1: No-show (El hogar no abre)
          _IncidentRadioTile(
            title: 'El hogar no atiende / Ausente',
            subtitle: 'Llegaste al domicilio, tocaste y esperaste sin respuesta del ciudadano.',
            icon: Icons.door_front_door_outlined,
            value: IncidentType.noShow,
            groupValue: _selectedType,
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),
          const SizedBox(height: 10),

          // Opción 2: Material no conforme
          _IncidentRadioTile(
            title: 'Material no conforme o contaminado',
            subtitle: 'Los residuos están mojados, con restos orgánicos o no corresponden a lo declarado.',
            icon: Icons.delete_sweep_outlined,
            value: IncidentType.rejectOnSite,
            groupValue: _selectedType,
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),
          const SizedBox(height: 10),

          // Opción 3: Abandono por avería
          _IncidentRadioTile(
            title: 'Emergencia o avería mecánica en ruta',
            subtitle: 'Problema con tu vehículo (desperfecto, pinchazo) que impide completar el recojo.',
            icon: Icons.build_circle_outlined,
            value: IncidentType.abandonRoute,
            groupValue: _selectedType,
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),
          const SizedBox(height: 16),

          // Campo opcional u obligatorio de detalle
          if (_selectedType == IncidentType.rejectOnSite ||
              _selectedType == IncidentType.abandonRoute) ...[
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _selectedType == IncidentType.rejectOnSite
                    ? 'Detalla el estado del residuo (Obligatorio)'
                    : 'Nota adicional o desperfecto (Opcional)',
                hintText: _selectedType == IncidentType.rejectOnSite
                    ? 'Ej. Residuos mezclados con comida y aceite'
                    : 'Ej. Falla en neumático de motocarga',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Volver a ruta'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC53030),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirmar y salir',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncidentRadioTile extends StatelessWidget {
  const _IncidentRadioTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final IncidentType value;
  final IncidentType groupValue;
  final ValueChanged<IncidentType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = (value == groupValue);

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? LivoraColors.forest.withValues(alpha: 0.06)
              : LivoraColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? LivoraColors.forest
                : LivoraColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? LivoraColors.forest : LivoraColors.deep,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: LivoraColors.deep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: LivoraColors.ink.withValues(alpha: 0.7),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<IncidentType>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: LivoraColors.forest,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
