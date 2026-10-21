import '../../models/models.dart';

/// Contrato formal de dominio para operaciones de billetera Web3 y transacciones LIVO.
/// Principio SOLID: Dependency Inversion Principle (DIP) e Interface Segregation (ISP).
abstract class IWalletRepository {
  /// Obtiene el saldo disponible de tokens LIVO con estrategia de refresco opcional.
  Future<String> getBalance({bool forceRefresh = false});

  /// Ejecuta transferencia de tokens LIVO hacia otra dirección Stellar.
  Future<Map<String, dynamic>> sendTokens({
    required String toAddress,
    required double amount,
  });

  /// Consulta detalles de un QR de redención o compra.
  Future<Map<String, dynamic>> getRedemptionDetails(String scannedCode);

  /// Confirma y liquida el canje de tokens con un comercio asociado.
  Future<Map<String, dynamic>> confirmRedemption(String scannedCode);

  /// Crea una sesión de pago / recarga de saldo mediante pasarela Izipay.
  Future<Map<String, dynamic>> createPaymentSession(double amount);

  /// Consulta el historial paginado de transacciones on-chain y off-chain.
  Future<List<WalletTransaction>> getTransactions({
    int page = 1,
    int limit = 20,
    String? direction,
  });
}
