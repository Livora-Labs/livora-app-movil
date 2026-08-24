import 'package:url_launcher/url_launcher.dart';

/// Utilidades de la red Stellar (la app migró de Arbitrum/EVM a Stellar/Soroban).
///
/// Las wallets son custodiadas por el backend: el usuario nunca maneja claves,
/// solo ve y comparte su dirección pública `G…`.
class Stellar {
  const Stellar._();

  /// Etiqueta de red que se muestra en la UI.
  static const networkLabel = 'Stellar Testnet';

  /// Red usada por el explorador (`testnet` o `public`).
  static const explorerNetwork = 'testnet';

  /// Una clave pública Stellar (ED25519) son 56 caracteres base32 que empiezan
  /// con `G`. El alfabeto base32 de Stellar es A–Z y 2–7, siempre en mayúscula.
  static final _addressPattern = RegExp(r'^G[A-Z2-7]{55}$');

  static bool isValidAddress(String? value) =>
      _addressPattern.hasMatch((value ?? '').trim());

  /// Normaliza lo que el usuario pega: Stellar distingue mayúsculas y la
  /// dirección siempre va en mayúscula.
  static String normalize(String value) => value.trim().toUpperCase();

  /// `GABC…WXYZ` para mostrar direcciones largas en espacios reducidos.
  static String short(String address, {int head = 6, int tail = 6}) {
    if (address.length <= head + tail + 1) return address;
    return '${address.substring(0, head)}…'
        '${address.substring(address.length - tail)}';
  }

  /// El backend devuelve `transactionId` con el hash real (64 hex) cuando la
  /// transacción salió on-chain, o un id sintético `relayer…` cuando el
  /// Relayer corrió en modo simulado. Solo el primero existe en el explorador.
  static final _txHashPattern = RegExp(r'^[0-9a-f]{64}$');

  static bool isValidTxHash(String? value) =>
      _txHashPattern.hasMatch((value ?? '').trim().toLowerCase());

  static Uri accountUrl(String address) => Uri.parse(
        'https://stellar.expert/explorer/$explorerNetwork/account/$address',
      );

  static Uri transactionUrl(String hash) => Uri.parse(
        'https://stellar.expert/explorer/$explorerNetwork/tx/$hash',
      );

  /// Abre una URL de Stellar Expert en el navegador externo.
  /// Devuelve `false` si el dispositivo no pudo abrirla.
  static Future<bool> openInExplorer(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}
