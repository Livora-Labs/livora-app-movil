import '../../domain/repositories/i_complaints_repository.dart';
import '../../services/livora_api.dart';

/// Repositorio desacoplado para el Libro de Reclamaciones Virtual (Ley N° 29571).
/// Implementa [IComplaintsRepository] aislando la lógica de envío e interacción HTTP.
class ComplaintsRepository implements IComplaintsRepository {
  ComplaintsRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  @override
  Future<Map<String, dynamic>> submitComplaint({
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
  }) {
    return _api.createComplaint(
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
  }

  @override
  Future<Map<String, dynamic>> getComplaintStatus({
    required String correlativeNumber,
    required String documentNumber,
  }) {
    return _api.trackComplaint(
      correlativeNumber: correlativeNumber,
      documentNumber: documentNumber,
    );
  }
}
