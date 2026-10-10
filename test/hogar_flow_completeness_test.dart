import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/features/hogar/create_request/widgets/create_assignment_mode_selector.dart';
import 'package:livora_labs/features/hogar/create_request/widgets/create_donation_switch.dart';
import 'package:livora_labs/features/hogar/request_detail/widgets/request_rating_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Hogar Flow Complete Requirements Tests', () {
    testWidgets('CreateDonationSwitch se renderiza e interactúa correctamente', (tester) async {
      bool donationValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CreateDonationSwitch(
                  isDonation: donationValue,
                  onChanged: (val) {
                    setState(() => donationValue = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Donación Solidaria'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(donationValue, isTrue);
      expect(find.text('100% donado'), findsOneWidget);
    });

    testWidgets('CreateAssignmentModeSelector permite alternar entre AUTOMATIC y AUCTION', (tester) async {
      String currentMode = 'AUTOMATIC';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CreateAssignmentModeSelector(
                  selectedMode: currentMode,
                  onModeChanged: (newMode) {
                    setState(() => currentMode = newMode);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Modo de Asignación'), findsOneWidget);
      expect(find.text('Asignación Rápida Automática'), findsOneWidget);
      expect(find.text('Subasta Ecológica Inversa'), findsOneWidget);

      // Cambiar a AUCTION
      await tester.tap(find.text('Subasta Ecológica Inversa'));
      await tester.pumpAndSettle();

      expect(currentMode, 'AUCTION');
    });

    testWidgets('RequestRatingCard permite calificar con estrellas y feedback (RF-12)', (tester) async {
      int? submittedRating;
      String? submittedFeedback;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestRatingCard(
              collectorName: 'Juan Pérez',
              isSubmitting: false,
              onSubmitRating: (rating, feedback) async {
                submittedRating = rating;
                submittedFeedback = feedback;
              },
            ),
          ),
        ),
      );

      expect(find.text('Califica a tu Recolector'), findsOneWidget);
      expect(find.text('Recolector: Juan Pérez'), findsOneWidget);
      // Hay 1 estrella en la cabecera y 5 estrellas en la fila interactiva (6 en total)
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(6));

      // Ingresar feedback
      await tester.enterText(find.byType(TextField), 'Excelente servicio, muy puntual');
      await tester.pumpAndSettle();

      // Enviar
      await tester.tap(find.text('Enviar Calificación'));
      await tester.pumpAndSettle();

      expect(submittedRating, 5);
      expect(submittedFeedback, 'Excelente servicio, muy puntual');
    });
  });
}
