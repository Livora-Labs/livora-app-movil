/// Contrato formal de dominio para el Libro de Reclamaciones Virtual (Ley N° 29571 / Indecopi).
/// Principio SOLID: Dependency Inversion Principle (DIP).
abstract class IComplaintsRepository {
  /// Registra una nueva reclamación formal (Queja o Reclamo) y genera el número correlativo legal.
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
  });

  /// Consulta el estado y trazabilidad de una reclamación mediante su número correlativo y DNI.
  Future<Map<String, dynamic>> getComplaintStatus({
    required String correlativeNumber,
    required String documentNumber,
  });
}
