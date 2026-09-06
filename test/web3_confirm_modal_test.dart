import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/widgets/web3_confirm_modal.dart';

void main() {
  testWidgets('Web3ConfirmModal renderiza montos, comercio y descargo legal verbatim',
      (WidgetTester tester) async {
    bool confirmed = false;
    bool cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Web3ConfirmModal(
            tokenAmount: 25.0,
            destinationName: 'Tienda Verde Miraflores',
            destinationAddress:
                'GDI6B7HL5S76PSL4GTCM6G4TQIGQ45VYHJLP7XXS332LGH4BSX6U5YQM',
            actionDescription: 'Canje de EcoTokens en Comercio Aliado',
            concept: 'Compra de Productos Eco-Amigables',
            warningText:
                'Al confirmar, autorizas a Livora a firmar la transacción en la blockchain Stellar. Esta acción es irreversible.',
            onConfirm: () => confirmed = true,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    // Verificar contenido del modal
    expect(find.text('Confirmar Transacción Blockchain'), findsOneWidget);
    expect(find.text('25.00 ECO'), findsOneWidget);
    expect(find.text('Tienda Verde Miraflores'), findsOneWidget);
    expect(find.text('Compra de Productos Eco-Amigables'), findsOneWidget);
    expect(find.text('0.00 ECO (Cubierto por Livora)'), findsOneWidget);
    expect(
      find.text(
        'Al confirmar, autorizas a Livora a firmar la transacción en la blockchain Stellar. Esta acción es irreversible.',
      ),
      findsOneWidget,
    );

    // Verificar interacciones de botones
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(confirmed, isTrue);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(cancelled, isTrue);
  });
}
