import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/models/models.dart';
import 'package:livora_labs/widgets/batch_detail_modal.dart';
import 'package:livora_labs/widgets/collection_request_detail_bottom_sheet.dart';
import 'package:livora_labs/widgets/wallet_transaction_voucher_modal.dart';

void main() {
  testWidgets('CollectionRequestDetailBottomSheet renderiza desglose de escrow, direccion y CTA',
      (WidgetTester tester) async {
    bool accepted = false;

    final request = CollectionRequest(
      id: 'req-12345678-abcd',
      status: 'PENDING',
      assignmentMode: 'AUCTION',
      itemsEstimated: {'PET': 10.0, 'CARTON': 5.0},
      agreedRates: {'PET': 2.0, 'CARTON': 1.0},
      householdName: 'Familia Perez',
      householdAddress: 'Av. Larco 1234, Miraflores, Lima',
      assignedCenterName: 'Planta Recicladora Sur',
      assignedCenterEmail: 'sur@livora.pe',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionRequestDetailBottomSheet(
            request: request,
            walletBalance: 50.0,
            onAccept: () => accepted = true,
            onRechargeNeeded: () {},
          ),
        ),
      ),
    );

    // Verificaciones de contenido
    expect(find.text('Solicitud #REQ-1234'), findsOneWidget);
    expect(find.text('Subasta ⚖️'), findsOneWidget);
    expect(find.text('Familia Perez'), findsOneWidget);
    expect(find.text('Av. Larco 1234, Miraflores, Lima'), findsOneWidget);
    expect(find.text('Planta Recicladora Sur'), findsOneWidget);

    // Desplazar hacia abajo para ver el desglose de Escrow
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Desglose de Escrow (Total: 10*2 + 5*1 = 25 PEN)
    expect(find.text('S/ 25.00 PEN'), findsOneWidget); // Total bruto
    expect(find.text('S/ 10.00 PEN'), findsOneWidget); // 40% Hogar
    expect(find.text('S/ 2.50 PEN'), findsOneWidget); // 10% Livora
    expect(find.text('S/ 12.50 PEN'), findsOneWidget); // 50% Recolector
    expect(find.text('12.50 ECO'), findsOneWidget); // Garantia a bloquear

    // Botón aceptar con saldo suficiente
    expect(find.text('Aceptar recolección (12.5 ECO)'), findsOneWidget);
    await tester.tap(find.text('Aceptar recolección (12.5 ECO)'));
    await tester.pump();
    expect(accepted, isTrue);
  });

  testWidgets('CollectionRequestDetailBottomSheet con saldo insuficiente muestra CTA de recarga',
      (WidgetTester tester) async {
    bool rechargeRequested = false;

    final request = CollectionRequest(
      id: 'req-87654321-efgh',
      status: 'PENDING',
      assignmentMode: 'AUTOMATIC',
      itemsEstimated: {'PET': 10.0},
      agreedRates: {'PET': 2.0},
      householdName: 'Carlos Rojas',
      householdAddress: 'Calle Las Begonias 450, San Isidro',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionRequestDetailBottomSheet(
            request: request,
            walletBalance: 2.0, // Insuficiente (requiere 10.0 ECO)
            onAccept: () {},
            onRechargeNeeded: () => rechargeRequested = true,
          ),
        ),
      ),
    );

    expect(find.text('Directa ⚡'), findsOneWidget);
    expect(find.text('Saldo insuficiente · Recargar vía Niubiz'), findsOneWidget);

    await tester.tap(find.text('Saldo insuficiente · Recargar vía Niubiz'));
    await tester.pump();
    expect(rechargeRequested, isTrue);
  });

  testWidgets('BatchDetailModal renderiza tabla comparativa de pesaje y hash de Stellar',
      (WidgetTester tester) async {
    final batch = Batch(
      id: 'batch-40e1c867-1111',
      status: 'RECEIVED',
      destinationCenterName: 'EcoPlanta Chorrillos',
      txHash: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f61234',
      materialsActual: {'PET': 18.5, 'CARTON': 10.0},
      requests: [
        CollectionRequest(
          id: 'req-1',
          status: 'COMPLETED',
          itemsEstimated: {'PET': 15.0, 'CARTON': 8.0},
          householdName: 'Residencial Los Sauces',
        ),
      ],
      createdAt: DateTime(2026, 9, 2, 14, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatchDetailModal(batch: batch),
        ),
      ),
    );

    expect(find.text('Lote #BATCH-40'), findsOneWidget);
    expect(find.text('EcoPlanta Chorrillos'), findsOneWidget);
    expect(find.text('Pesaje Comparativo en Báscula'), findsOneWidget);
    expect(find.text('18.5 kg'), findsOneWidget); // Real Báscula PET
    expect(find.text('10 kg'), findsOneWidget); // Real Báscula Cartón
    expect(find.text('28.5 kg'), findsOneWidget); // Total Real
    expect(find.text('Ver Comprobante en Stellar Expert'), findsOneWidget);
  });

  testWidgets('WalletTransactionVoucherModal renderiza monto, contraparte y trazabilidad',
      (WidgetTester tester) async {
    final tx = WalletTransaction(
      id: 'tx-uuid-99998888',
      type: 'RECOMPENSA_RECICLAJE',
      amount: 40.0,
      direction: 'IN',
      recipientName: 'Centro de Acopio Livora Sur',
      recipientWallet: 'GDI6B7HL5S76PSL4GTCM6G4TQIGQ45VYHJLP7XXS332LGH4BSX6U5YQM',
      txHash: '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff',
      createdAt: DateTime(2026, 9, 2, 16, 20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletTransactionVoucherModal(transaction: tx),
        ),
      ),
    );

    expect(find.text('+40.00 ECO'), findsOneWidget);
    expect(find.text('≈ S/ 40.00 PEN'), findsOneWidget);
    expect(find.text('Recompensa por Reciclaje'), findsOneWidget);
    expect(find.text('Centro de Acopio Livora Sur'), findsOneWidget);
    expect(find.text('Confirmado en Stellar'), findsOneWidget);
    expect(find.text('Ver en Stellar Expert'), findsOneWidget);
  });
}
