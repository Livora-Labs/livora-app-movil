import 'package:flutter/foundation.dart';
import '../../../../domain/repositories/i_complaints_repository.dart';
import '../../../../domain/state/ui_state.dart';

/// ViewModel desacoplado para el Libro de Reclamaciones Virtual (Ley N° 29571).
/// Implementa SRP aislando validación, registro y trazabilidad de reclamaciones.
class ComplaintsViewModel extends ChangeNotifier {
  ComplaintsViewModel({
    required IComplaintsRepository repository,
  }) : _repository = repository;

  final IComplaintsRepository _repository;

  UIState<Map<String, dynamic>> _submitState = const UIState.initial();
  UIState<Map<String, dynamic>> get submitState => _submitState;

  Map<String, dynamic>? _registeredComplaint;
  Map<String, dynamic>? get registeredComplaint => _registeredComplaint;

  bool get isSubmitting => _submitState.isLoading;

  /// Registra una nueva reclamación ciudadana.
  Future<Map<String, dynamic>?> submitComplaint({
    required String documentType,
    required String documentNumber,
    required String fullName,
    required String address,
    required String phone,
    required String email,
    required bool isMinor,
    String? representativeName,
    String? representativeDoc,
    required String goodType,
    required String goodDescription,
    double? amount,
    required String claimType,
    required String claimDetail,
    required String consumerRequest,
  }) async {
    _submitState = const UIState.loading();
    notifyListeners();

    try {
      final res = await _repository.submitComplaint(
        documentType: documentType,
        documentNumber: documentNumber,
        fullName: fullName,
        address: address,
        phone: phone,
        email: email,
        isMinor: isMinor,
        representativeName: representativeName,
        representativeDoc: representativeDoc,
        goodType: goodType,
        goodDescription: goodDescription,
        amount: amount,
        claimType: claimType,
        claimDetail: claimDetail,
        consumerRequest: consumerRequest,
      );

      _registeredComplaint = res;
      _submitState = UIState.success(res);
      notifyListeners();
      return res;
    } catch (e) {
      _submitState = UIState.error(
        e.toString().replaceAll('Exception: ', ''),
        isNetworkError: true,
      );
      notifyListeners();
      return null;
    }
  }

  /// Consulta el estado público de una reclamación mediante correlativo y documento de identidad.
  Future<Map<String, dynamic>?> trackComplaintStatus({
    required String correlativeNumber,
    required String documentNumber,
  }) async {
    try {
      return await _repository.getComplaintStatus(
        correlativeNumber: correlativeNumber,
        documentNumber: documentNumber,
      );
    } catch (_) {
      return null;
    }
  }

  void reset() {
    _submitState = const UIState.initial();
    _registeredComplaint = null;
    notifyListeners();
  }
}
