// test/widget/confirmation_modal_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/core/constants/medical_constants.dart';
import 'package:insulin_assistant/presentation/screens/calculator/confirmation_modal.dart';

Widget _modal({
  double dose = 4.5,
  VoidCallback? onConfirm,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: ConfirmationModal(
            doseUnits: dose,
            onConfirm: onConfirm ?? () {},
          ),
        ),
      ),
    );

void main() {
  group('ConfirmationModal Widget Tests', () {
    testWidgets('Displays dose value prominently', (tester) async {
      await tester.pumpWidget(_modal(dose: 4.5));
      // The dose number "4.5" should be visible
      expect(find.text('4.5'), findsWidgets);
    });

    testWidgets('Shows countdown text initially', (tester) async {
      await tester.pumpWidget(_modal());
      // Should show waiting text
      expect(
        find.textContaining('انتظر'),
        findsWidgets,
      );
    });

    testWidgets('Confirm button appears ONLY after delay', (tester) async {
      await tester.pumpWidget(_modal());

      // Immediately: no confirm button
      expect(find.text('تأكيد — أنا متأكد'), findsNothing);

      // After the mandatory delay
      await tester.pump(
        Duration(seconds: MedicalConstants.doseConfirmationDelaySeconds + 1),
      );
      await tester.pumpAndSettle();

      expect(find.text('تأكيد — أنا متأكد'), findsOneWidget);
    });

    testWidgets('Cancel button always visible', (tester) async {
      await tester.pumpWidget(_modal());
      expect(find.text('إلغاء'), findsOneWidget);
    });

    testWidgets('onConfirm fires when confirm button is tapped after delay',
        (tester) async {
      var confirmed = false;
      await tester.pumpWidget(_modal(onConfirm: () => confirmed = true));

      // Advance past delay
      await tester.pump(
        Duration(seconds: MedicalConstants.doseConfirmationDelaySeconds + 1),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('تأكيد — أنا متأكد'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets('Modal title is correct', (tester) async {
      await tester.pumpWidget(_modal());
      expect(find.text('تأكيد الحقن'), findsOneWidget);
    });

    testWidgets('Delay constant matches MedicalConstants', (tester) async {
      // Verify the MedicalConstants value is > 0 (clinical requirement)
      expect(MedicalConstants.doseConfirmationDelaySeconds, greaterThan(0));
      // And a reasonable value (1–10 seconds)
      expect(MedicalConstants.doseConfirmationDelaySeconds, inInclusiveRange(1, 10));
    });
  });
}
