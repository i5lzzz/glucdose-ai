// test/widget/calculator_widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insulin_assistant/presentation/providers/app_providers.dart';
import 'package:insulin_assistant/presentation/screens/calculator/calculator_screen.dart';
import 'package:insulin_assistant/presentation/theme/design_tokens.dart';
import 'package:insulin_assistant/presentation/widgets/shared/ia_button.dart';
import 'package:insulin_assistant/presentation/widgets/shared/safety_banner.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Cairo'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    );

void main() {
  group('CalculatorScreen Widget Tests', () {
    testWidgets('Renders calculate button initially', (tester) async {
      await tester.pumpWidget(_wrap(const CalculatorScreen()));
      expect(find.text('احسب الجرعة'), findsOneWidget);
    });

    testWidgets('Shows placeholder dose "—" before calculation', (tester) async {
      await tester.pumpWidget(_wrap(const CalculatorScreen()));
      expect(find.text('—'), findsWidgets); // dose and possibly others
    });

    testWidgets('Close button navigates back', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const CalculatorScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CalculatorScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CalculatorScreen), findsNothing);
    });

    testWidgets('Displays warning safety banner when level is warning', (tester) async {
      await tester.pumpWidget(
        _wrap(const SafetyBanner(
          level: 'warning',
          messageAr: 'سكر الدم منخفض',
        )),
      );
      expect(find.text('سكر الدم منخفض'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Displays hard block safety banner with block icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const SafetyBanner(
          level: 'hardBlock',
          messageAr: 'خطر شديد',
        )),
      );
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    });

    testWidgets('IAButton renders label', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(IAButton(
        label: 'احسب',
        onPressed: () => tapped = true,
      )));
      expect(find.text('احسب'), findsOneWidget);
      await tester.tap(find.byType(IAButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('Disabled IAButton does not fire onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(IAButton(
        label: 'احسب',
        onPressed: null, // disabled
      )));
      await tester.tap(find.byType(IAButton), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('Loading IAButton shows CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(IAButton(
        label: 'احسب',
        onPressed: () {},
        isLoading: true,
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('احسب'), findsNothing); // hidden during loading
    });
  });

  group('CalculatorState Provider', () {
    test('Initial state has idle status and empty inputs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(calculatorProvider);
      expect(state.bgInput, isEmpty);
      expect(state.carbsInput, isEmpty);
      expect(state.status, equals(CalcStatus.idle));
      expect(state.calculatedDose, isNull);
    });

    test('Setting inputs updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(calculatorProvider.notifier).setBGInput('150');
      container.read(calculatorProvider.notifier).setCarbsInput('60');
      final state = container.read(calculatorProvider);
      expect(state.bgInput, equals('150'));
      expect(state.carbsInput, equals('60'));
    });

    test('Reset clears all fields', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(calculatorProvider.notifier).setBGInput('150');
      container.read(calculatorProvider.notifier).reset();
      expect(container.read(calculatorProvider).bgInput, isEmpty);
    });

    test('Calculate with valid inputs produces result', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);
      notifier.setBGInput('150');
      notifier.setCarbsInput('60');
      await notifier.calculate();
      final state = container.read(calculatorProvider);
      expect(state.status, equals(CalcStatus.result));
      expect(state.calculatedDose, isNotNull);
      expect(state.calculatedDose! >= 0, isTrue);
    });

    test('BG=39 produces hardBlock safety level', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);
      notifier.setBGInput('39');
      notifier.setCarbsInput('0');
      await notifier.calculate();
      final state = container.read(calculatorProvider);
      expect(state.safetyLevel, equals('hardBlock'));
      expect(state.canConfirm, isFalse);
    });

    test('BG=65 produces warning safety level', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);
      notifier.setBGInput('65');
      notifier.setCarbsInput('60');
      await notifier.calculate();
      final state = container.read(calculatorProvider);
      expect(state.safetyLevel, equals('warning'));
      expect(state.safetyMessageAr, isNotNull);
    });

    test('Normal BG produces safe level and can confirm', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);
      notifier.setBGInput('150');
      notifier.setCarbsInput('60');
      await notifier.calculate();
      final state = container.read(calculatorProvider);
      expect(state.safetyLevel, equals('safe'));
      expect(state.canConfirm, isTrue);
    });
  });

  group('UserSettings Provider', () {
    test('Default settings are clinically safe defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final s = container.read(userSettingsProvider);
      expect(s.icr, greaterThan(0));
      expect(s.isf, greaterThan(0));
      expect(s.targetBG, greaterThan(70));
      expect(s.targetBG, lessThan(200));
      expect(s.maxDose, greaterThan(0));
      expect(s.maxDose, lessThanOrEqualTo(20));
    });

    test('Toggling units changes glucose unit', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final before = container.read(userSettingsProvider).unitSystem.glucose;
      container.read(userSettingsProvider.notifier).toggleUnits();
      final after = container.read(userSettingsProvider).unitSystem.glucose;
      expect(after, isNot(equals(before)));
    });
  });
}
