import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/session.dart';
import '../../../../screens/hogar/request_detail_screen.dart';
import '../../../../screens/hogar/widgets/hogar_active_address_bar.dart';
import '../../../../services/livora_api.dart';
import '../../../../widgets/common.dart';
import '../view_model/create_request_view_model.dart';
import '../widgets/create_assignment_mode_selector.dart';
import '../widgets/create_confirmation_summary_card.dart';
import '../widgets/create_donation_switch.dart';
import '../widgets/create_location_picker_card.dart';
import '../widgets/create_materials_selector.dart';
import '../widgets/create_photo_uploader.dart';
import '../widgets/create_quote_summary_card.dart';
import '../widgets/create_request_stepper_header.dart';

/// Vista interactiva para la creación de solicitudes de reciclaje (Hogar).
/// Implementada como un Wizard de 3 Pasos con PageView y Stepper.
class CreateRequestView extends StatelessWidget {
  const CreateRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CreateRequestViewModel(
        api: ctx.read<LivoraApi>(),
      ),
      child: const _CreateRequestContent(),
    );
  }
}

class _CreateRequestContent extends StatefulWidget {
  const _CreateRequestContent();

  @override
  State<_CreateRequestContent> createState() => _CreateRequestContentState();
}

class _CreateRequestContentState extends State<_CreateRequestContent> {
  final _pageController = PageController();
  int _currentStep = 0;

  final _addressController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final MapController _mapController = MapController();

  static const _stepTitles = [
    'Materiales y Donación',
    'Ubicación y Evidencia',
    'Modo y Confirmación',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final user = context.read<SessionController>().user;
      final vm = context.read<CreateRequestViewModel>();

      vm.addListener(() {
        if (mounted && vm.address.isNotEmpty && _addressController.text != vm.address) {
          _addressController.text = vm.address;
        }
      });

      if (user?.latitude != null && user?.longitude != null) {
        vm.setCoordinates(user!.latitude!, user.longitude!);
        _mapController.move(LatLng(user.latitude!, user.longitude!), 15.5);
      } else {
        await vm.fetchCurrentGps();
        if (mounted) {
          _mapController.move(LatLng(vm.latitude, vm.longitude), 15.5);
        }
      }

      if (user?.address != null && user!.address!.isNotEmpty) {
        _addressController.text = user.address!;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _addressController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final vm = context.read<CreateRequestViewModel>();
    if (_currentStep == 0) {
      if (vm.totalKg < 0.5) {
        showAppSnack(context, 'Debes agregar al menos 0.5 kg de material para continuar', error: true);
        return;
      }
    } else if (_currentStep == 1) {
      if (_addressController.text.trim().isEmpty) {
        showAppSnack(context, 'Por favor especifica la dirección de recolección', error: true);
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSubmit() async {
    final vm = context.read<CreateRequestViewModel>();

    if (vm.totalKg < 0.5) {
      showAppSnack(context, 'El peso total mínimo es de 0.5 kg', error: true);
      return;
    }

    final modeLabel = vm.assignmentMode == 'AUCTION' ? 'Subasta Ecológica' : 'Asignación Automática';
    final confirmed = await confirmDialog(
      context,
      title: 'Publicar Solicitud',
      message: '¿Confirmas la solicitud de ${vm.totalKg.toStringAsFixed(1)} kg bajo el modo $modeLabel?',
      confirmLabel: 'Confirmar y Publicar',
    );
    if (!confirmed || !mounted) return;

    final req = await vm.submitRequest(
      fullAddress: _addressController.text.trim(),
      reference: _referenceController.text.trim(),
      notes: _notesController.text.trim(),
      isDonation: vm.isDonation,
    );

    if (mounted) {
      if (req != null) {
        final session = context.read<SessionController>();
        session.updateActiveRequest(req);
        session.notifyBatchesChanged();

        showAppSnack(context, '¡Solicitud publicada exitosamente!');

        // Redirigir directamente al detalle de la solicitud para ver PIN o bids
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetailScreen(requestId: req.id),
          ),
        );
      } else {
        showAppSnack(context, 'Error al registrar la solicitud', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateRequestViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Recolección'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _prevStep,
        ),
      ),
      body: Column(
        children: [
          CreateRequestStepperHeader(
            currentStep: _currentStep,
            totalSteps: 3,
            stepTitles: _stepTitles,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // PASO 1: Materiales, Pesos, Cotización en Vivo y Donación Solidaria
                _buildStep1Materials(vm),

                // PASO 2: Ubicación en Mapa, Dirección, Referencia y Foto
                _buildStep2LocationAndPhoto(vm),

                // PASO 3: Selección de Modo (Automático / Subasta) y Confirmación
                _buildStep3ModeAndConfirmation(vm),
              ],
            ),
          ),
          _buildBottomActionBar(vm),
        ],
      ),
    );
  }

  Widget _buildStep1Materials(CreateRequestViewModel vm) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        CreateMaterialsSelector(
          materials: vm.materials,
          onWeightChanged: (mat, wt) => vm.updateMaterialWeight(mat, wt),
        ),
        const SizedBox(height: 14),
        CreateDonationSwitch(
          isDonation: vm.isDonation,
          onChanged: (val) => vm.setIsDonation(val),
        ),
        const SizedBox(height: 14),
        CreateQuoteSummaryCard(
          totalKg: vm.totalKg,
          estimatedPen: vm.estimatedMarketPEN,
          estimatedLivo: vm.estimatedLivoReward,
          co2Kg: vm.estimatedCo2Saved,
          waterLiters: vm.estimatedWaterSaved,
          isDonation: vm.isDonation,
        ),
      ],
    );
  }

  Widget _buildStep2LocationAndPhoto(CreateRequestViewModel vm) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        CreateLocationPickerCard(
          mapController: _mapController,
          latitude: vm.latitude,
          longitude: vm.longitude,
          addressController: _addressController,
          referenceController: _referenceController,
          isGeocoding: vm.isGeocodingAddress,
          isFetchingGps: vm.isFetchingLocation,
          onGpsPressed: () => vm.fetchCurrentGps(),
          onPositionChanged: (lat, lng) => vm.setCoordinates(lat, lng),
          onChangeAddressTap: () async {
            final user = context.read<SessionController>().user;
            final res = await showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddressSelectorBottomSheet(user: user),
            );
            if (res != null && mounted) {
              final newAddr = res['address'] as String?;
              final newLat = res['latitude'] as double?;
              final newLng = res['longitude'] as double?;
              if (newAddr != null) {
                _addressController.text = newAddr;
                vm.setAddress(newAddr);
              }
              if (newLat != null && newLng != null) {
                vm.setCoordinates(newLat, newLng);
              }
            }
          },
        ),
        const SizedBox(height: 14),
        CreatePhotoUploader(
          photo: vm.photo,
          isUploading: vm.uploadingPhoto,
          onPickPhoto: (source) => vm.pickAndUploadPhoto(source),
          onRemovePhoto: () => vm.removePhoto(),
        ),
      ],
    );
  }

  Widget _buildStep3ModeAndConfirmation(CreateRequestViewModel vm) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        CreateAssignmentModeSelector(
          selectedMode: vm.assignmentMode,
          onModeChanged: (mode) => vm.setAssignmentMode(mode),
        ),
        const SizedBox(height: 16),
        CreateConfirmationSummaryCard(
          assignmentMode: vm.assignmentMode,
          isDonation: vm.isDonation,
          materials: vm.materials,
          address: _addressController.text.trim(),
          totalKg: vm.totalKg,
          estimatedPen: vm.estimatedMarketPEN,
          estimatedLivo: vm.estimatedLivoReward,
          co2Kg: vm.estimatedCo2Saved,
          hasPhoto: vm.photoUrl != null || vm.photo != null,
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(CreateRequestViewModel vm) {
    final isLastStep = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: LivoraColors.deep,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _prevStep,
              child: const Text('Atrás', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LivoraColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              onPressed: vm.isBusy ? null : (isLastStep ? _handleSubmit : _nextStep),
              child: vm.isBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isLastStep ? 'Publicar Solicitud' : 'Continuar',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
