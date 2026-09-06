import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/core/stellar.dart';

void main() {
  // Dirección de ejemplo del propio backend (CreateTransactionDto).
  const validAddress =
      'GA3LZ7ROA3YAYOY52J5TDLDDMDADCCZ3CV6CXVQE4SUQGCAB732QXGEB';

  group('Stellar.isValidAddress', () {
    test('acepta una clave pública G… de 56 caracteres', () {
      expect(Stellar.isValidAddress(validAddress), isTrue);
      expect(validAddress.length, 56);
    });

    test('acepta espacios alrededor', () {
      expect(Stellar.isValidAddress('  $validAddress  '), isTrue);
    });

    test('rechaza direcciones EVM del entorno anterior', () {
      expect(
        Stellar.isValidAddress('0x71C7656EC7ab88b098defB751B7401B5f6d8976F'),
        isFalse,
      );
    });

    test('rechaza longitudes incorrectas y caracteres fuera de base32', () {
      expect(Stellar.isValidAddress('${validAddress}A'), isFalse);
      expect(
        Stellar.isValidAddress(validAddress.substring(0, 55)),
        isFalse,
      );
      // 0, 1 y 8 no existen en el alfabeto base32 de Stellar.
      expect(
        Stellar.isValidAddress('G0${validAddress.substring(2)}'),
        isFalse,
      );
    });

    test('rechaza minúsculas sin normalizar y las acepta ya normalizadas', () {
      final lower = validAddress.toLowerCase();
      expect(Stellar.isValidAddress(lower), isFalse);
      expect(Stellar.isValidAddress(Stellar.normalize(lower)), isTrue);
    });

    test('rechaza nulo y vacío', () {
      expect(Stellar.isValidAddress(null), isFalse);
      expect(Stellar.isValidAddress('   '), isFalse);
    });
  });

  group('Stellar.isValidTxHash', () {
    test('acepta un hash de 64 hex', () {
      expect(Stellar.isValidTxHash('a' * 64), isTrue);
    });

    test('rechaza el id sintético del Relayer en modo simulado', () {
      expect(Stellar.isValidTxHash('relayer18f3c2a1b9d4e7f0'), isFalse);
    });

    test('rechaza longitudes distintas de 64', () {
      expect(Stellar.isValidTxHash('a' * 63), isFalse);
      expect(Stellar.isValidTxHash('a' * 65), isFalse);
    });
  });

  group('URLs de Stellar Expert', () {
    test('apuntan a testnet', () {
      expect(
        Stellar.accountUrl(validAddress).toString(),
        'https://stellar.expert/explorer/testnet/account/$validAddress',
      );
      expect(
        Stellar.transactionUrl('a' * 64).toString(),
        'https://stellar.expert/explorer/testnet/tx/${'a' * 64}',
      );
    });
  });

  group('Stellar.short', () {
    test('acorta direcciones largas y deja las cortas intactas', () {
      expect(Stellar.short(validAddress), 'GA3LZ7…2QXGEB');
      expect(Stellar.short('GABC'), 'GABC');
    });
  });

  group('Stellar open helpers validation', () {
    test('openAccountInExplorer retorna false con dirección inválida', () async {
      expect(await Stellar.openAccountInExplorer('0xInvalidEVM'), isFalse);
      expect(await Stellar.openAccountInExplorer(null), isFalse);
    });

    test('openTxInExplorer retorna false con hash inválido o sintético', () async {
      expect(await Stellar.openTxInExplorer('relayer18f3c2a1b9d4e7f0'), isFalse);
      expect(await Stellar.openTxInExplorer('short-hash'), isFalse);
      expect(await Stellar.openTxInExplorer(null), isFalse);
    });
  });
}
