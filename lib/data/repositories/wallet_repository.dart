import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../local/app_local_cache.dart';

/// Repositorio desacoplado para operaciones financieras y criptográficas de billetera.
/// Integra lectura Offline-First con SWR y caché Hive no-volátil.
class WalletRepository {
  final LivoraApi _api;
  final SessionController? _session;

  WalletRepository(this._api, [this._session]);

  /// Obtiene el saldo disponible de LIVOs consultando el nodo/relayer con fallback en caché Hive.
  Future<String> getBalance({bool forceRefresh = false}) async {
    final role = _session?.user?.role ?? 'generic';
    final cached = AppLocalCache.getWalletBalance(role);

    if (cached != null && !forceRefresh) {
      // Retorna de inmediato la caché y dispara refresco en background
      _api.walletBalance().then((fresh) {
        AppLocalCache.putWalletBalance(role, fresh);
      }).catchError((_) {});
      return cached;
    }

    try {
      final balance = await _api.walletBalance();
      await AppLocalCache.putWalletBalance(role, balance);
      return balance;
    } catch (e) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Realiza transferencia directa de tokens LIVOs firmada por el backend en Stellar.
  Future<Map<String, dynamic>> sendTokens({
    required String toAddress,
    required double amount,
  }) async {
    final result = await _api.sendTokens(toAddress: toAddress, amount: amount);
    // Invalida saldo local para sincronizar el nuevo balance
    final role = _session?.user?.role ?? 'generic';
    final fresh = await _api.walletBalance().catchError((_) => '0.00');
    await AppLocalCache.putWalletBalance(role, fresh);
    return result;
  }

  /// Consulta el detalle de un cobro QR para redención de cupones / beneficios.
  Future<Map<String, dynamic>> getRedemptionDetails(String scannedCode) {
    return _api.redemptionDetails(scannedCode);
  }

  /// Ejecuta el canje de tokens con el comercio asociado.
  Future<Map<String, dynamic>> confirmRedemption(String scannedCode) async {
    final result = await _api.confirmRedemption(scannedCode);
    final role = _session?.user?.role ?? 'generic';
    final fresh = await _api.walletBalance().catchError((_) => '0.00');
    await AppLocalCache.putWalletBalance(role, fresh);
    return result;
  }

  /// Crea una sesión de pago / recarga con Izipay.
  Future<Map<String, dynamic>> createPaymentSession(double amount) {
    return _api.createPaymentSession(amount: amount);
  }

  /// Obtiene el historial paginado de transacciones de la billetera.
  Future<List<WalletTransaction>> getTransactions({int page = 1, int limit = 20, String? direction}) {
    return _api.walletTransactions(page: page, limit: limit, direction: direction);
  }
}
