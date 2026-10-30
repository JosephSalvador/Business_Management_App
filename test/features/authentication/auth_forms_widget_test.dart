import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/app/theme/app_theme.dart';
import 'package:jolinx_app/features/authentication/presentation/pages/register_page.dart';
import 'package:jolinx_app/features/authentication/presentation/widgets/password_field.dart';

Widget _host(Widget child) => ProviderScope(
      // The app theme registers AppSemanticColors, which widgets such as
      // PasswordStrengthMeter read via Theme.of(context).extension.
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
    );

void main() {
  group('PasswordField', () {
    testWidgets('toggles visibility', (tester) async {
      final controller = TextEditingController(text: 'Passw0rd!');
      await tester.pumpWidget(_host(PasswordArea(controller: controller)));

      expect(find.byType(EditableText), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isFalse,
      );
    });
  });

  group('RegisterPage', () {
    Future<void> pumpRegister(WidgetTester tester) async {
      await tester.pumpWidget(_host(const RegisterPage()));
      await tester.pumpAndSettle();
    }

    Future<void> fillIdentity(WidgetTester tester) async {
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Jina lako kamili'), 'Mama Lishe');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Barua pepe'), 'mama@duka.tz');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Namba ya simu'), '0712345678');
    }

    testWidgets('owners see identity fields and no invitation code',
        (tester) async {
      await pumpRegister(tester);

      expect(find.text('Mmiliki'), findsOneWidget);
      expect(find.text('Mfanyakazi'), findsOneWidget);
      // No business-name field on the register form — naming happens in the
      // onboarding wizard, so all identity fields are visible but the code is
      // only for staff.
      expect(find.widgetWithText(TextFormField, 'Jina la biashara (si lazima)'),
          findsNothing);
      expect(
          find.widgetWithText(TextFormField, 'Namba ya mwaliko'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('staff toggle reveals the invitation code field',
        (tester) async {
      await pumpRegister(tester);

      await tester.tap(find.text('Mfanyakazi'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Namba ya mwaliko'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    Future<void> submitWaitingForTerms(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Fungua akaunti'));
      await tester.tap(find.text('Fungua akaunti'));
      await tester.pump();
    }

    testWidgets('mismatched confirmation is rejected locally', (tester) async {
      await pumpRegister(tester);

      await fillIdentity(tester);
      final passwordFields = find.byType(PasswordField);
      await tester.enterText(passwordFields.first, 'Passw0rd!');
      await tester.enterText(passwordFields.last, 'Different1!');

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await submitWaitingForTerms(tester);

      expect(find.text('Maneno ya siri hayafanani'), findsOneWidget);
    });

    testWidgets('password missing special character is rejected locally',
        (tester) async {
      await pumpRegister(tester);

      await fillIdentity(tester);
      final passwordFields = find.byType(PasswordField);
      await tester.enterText(passwordFields.first, 'Jolinx12345');
      await tester.enterText(passwordFields.last, 'Jolinx12345');

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await submitWaitingForTerms(tester);

      expect(find.textContaining('alama maalum'), findsOneWidget);
    });

    testWidgets('strength meter appears while typing a password',
        (tester) async {
      await pumpRegister(tester);

      final passwordFields = find.byType(PasswordField);
      await tester.enterText(passwordFields.first, 'Passw0rd!');
      await tester.pump();

      expect(find.text('Imara'), findsNothing);
      expect(
        find.textContaining(RegExp(r'Dhaifu|Wastani|Nzuri|Imara')),
        findsOneWidget,
      );
    });
  });
}

/// Wraps [PasswordField] so the toggle test does not need a full form.
class PasswordArea extends StatelessWidget {
  const PasswordArea({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) =>
      PasswordField(controller: controller, labelText: 'Neno la siri');
}
