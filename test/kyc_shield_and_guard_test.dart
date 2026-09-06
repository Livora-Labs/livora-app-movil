import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/models/models.dart';
import 'package:livora_labs/widgets/collection_request_detail_bottom_sheet.dart';
import 'package:livora_labs/widgets/kyc_required_bottom_sheet.dart';
import 'package:livora_labs/widgets/kyc_status_shield.dart';

void main() {
  group('KycStatus Enum & Model parsing', () {
    test('KycStatus.fromString parsea todos los estados de backend', () {
      expect(KycStatus.fromString('NOT_SUBMITTED'), KycStatus.unverified);
      expect(KycStatus.fromString('pending'), KycStatus.pending);
      expect(KycStatus.fromString('APPROVED'), KycStatus.approved);
      expect(KycStatus.fromString('REJECTED'), KycStatus.rejected);
      expect(KycStatus.fromString(null), KycStatus.unverified);
      expect(KycStatus.fromString('UNKNOWN_XYZ'), KycStatus.unverified);
    });

    test('KycStatus serializa a formato backend y etiquetas legibles', () {
      expect(KycStatus.unverified.toBackendString(), 'NOT_SUBMITTED');
      expect(KycStatus.pending.toBackendString(), 'PENDING');
      expect(KycStatus.approved.toBackendString(), 'APPROVED');
      expect(KycStatus.rejected.toBackendString(), 'REJECTED');

      expect(KycStatus.unverified.label, 'Sin verificar');
      expect(KycStatus.approved.label, 'Verificado');
    });

    test('KycApplication expone kycStatus mapeado correctamente', () {
      final app = KycApplication(status: 'APPROVED');
      expect(app.kycStatus, KycStatus.approved);
      expect(app.isApproved, isTrue);
      expect(app.canSubmit, isFalse);
    });
  });

  group('KycStatusShield Widget', () {
    testWidgets('KycStatusShield renderiza para estado unverified',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: KycStatusShield(overrideStatus: KycStatus.unverified),
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.shield_outlined);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('KycStatusShield renderiza para estado approved',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: KycStatusShield(overrideStatus: KycStatus.approved),
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.verified_user_rounded);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('KycStatusShield renderiza para estado pending',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: KycStatusShield(overrideStatus: KycStatus.pending),
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.hourglass_top_rounded);
      expect(iconFinder, findsOneWidget);
    });
  });

  group('KycRequiredBottomSheet Widget', () {
    testWidgets('KycRequiredBottomSheet renderiza advertencia para unverified',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KycRequiredBottomSheet(kycStatus: KycStatus.unverified),
          ),
        ),
      );

      expect(find.text('Verificación de Identidad Requerida'), findsOneWidget);
      expect(find.text('Completar Verificación'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('KycRequiredBottomSheet renderiza auditoría para pending',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KycRequiredBottomSheet(kycStatus: KycStatus.pending),
          ),
        ),
      );

      expect(find.text('Verificación en Revisión'), findsOneWidget);
      expect(find.text('Ver Estado de Documentos'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('KycRequiredBottomSheet renderiza rechazo para rejected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KycRequiredBottomSheet(kycStatus: KycStatus.rejected),
          ),
        ),
      );

      expect(find.text('Verificación Rechazada'), findsOneWidget);
      expect(find.text('Reintentar Verificación'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_bad_rounded), findsOneWidget);
    });
  });

  group('Jerarquía Estricta en CollectionRequestDetailBottomSheet', () {
    final sampleRequest = CollectionRequest(
      id: 'req-guard-test',
      status: 'PENDING',
      assignmentMode: 'AUTOMATIC',
      itemsEstimated: {'PET': 10.0},
      agreedRates: {'PET': 2.0},
      householdName: 'Ana María',
      householdAddress: 'Av. Arequipa 2020, Lince',
    );

    testWidgets(
        'Si no está verificado (unverified), CTA exige KYC aunque tenga saldo suficiente',
        (WidgetTester tester) async {
      bool kycTriggered = false;
      bool accepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectionRequestDetailBottomSheet(
              request: sampleRequest,
              walletBalance: 100.0, // Saldo de sobra
              kycStatus: KycStatus.unverified,
              onKycRequired: () => kycTriggered = true,
              onAccept: () => accepted = true,
              onRechargeNeeded: () {},
            ),
          ),
        ),
      );

      expect(find.text('Verificar Identidad para Aceptar'), findsOneWidget);
      expect(find.text('Aceptar recolección (10.0 ECO)'), findsNothing);

      await tester.tap(find.text('Verificar Identidad para Aceptar'));
      await tester.pump();

      expect(kycTriggered, isTrue);
      expect(accepted, isFalse);
    });

    testWidgets(
        'Si está verificado (approved) y tiene saldo suficiente, CTA permite Aceptar',
        (WidgetTester tester) async {
      bool accepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectionRequestDetailBottomSheet(
              request: sampleRequest,
              walletBalance: 100.0, // Suficiente (requiere 10.0 ECO)
              kycStatus: KycStatus.approved,
              onAccept: () => accepted = true,
              onRechargeNeeded: () {},
            ),
          ),
        ),
      );

      expect(find.text('Aceptar recolección (10.0 ECO)'), findsOneWidget);

      await tester.tap(find.text('Aceptar recolección (10.0 ECO)'));
      await tester.pump();

      expect(accepted, isTrue);
    });

    testWidgets(
        'Si está verificado (approved) pero saldo insuficiente, CTA muestra Recarga Niubiz',
        (WidgetTester tester) async {
      bool rechargeTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectionRequestDetailBottomSheet(
              request: sampleRequest,
              walletBalance: 5.0, // Insuficiente (requiere 10.0 ECO)
              kycStatus: KycStatus.approved,
              onAccept: () {},
              onRechargeNeeded: () => rechargeTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Saldo insuficiente · Recargar vía Niubiz'), findsOneWidget);

      await tester.tap(find.text('Saldo insuficiente · Recargar vía Niubiz'));
      await tester.pump();

      expect(rechargeTriggered, isTrue);
    });
  });
}
