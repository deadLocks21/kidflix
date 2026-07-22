import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/resend_otp.usecase.dart';
import 'package:kidflix/core/application/usecases/verify_otp.usecase.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/otp_verify/otp_verify.page.dart';
import 'package:kidflix/ui/pages/otp_verify/widgets/otp_digit_field.widget.dart';

/// Non-régression du spinner infini : `verifyOtp` qui lève ne doit pas
/// laisser l'écran bloqué sur son indicateur de chargement.
///
/// Le bug d'origine venait du `setState(() => _isSubmitting = false)`
/// placé après l'`await` : l'exception traversait l'`await`, la ligne
/// n'était jamais atteinte, et seul un redémarrage de l'app en sortait.
void main() {
  final phone = PhoneNumber.parse('0612345678');

  Widget app(SessionController Function() controller) => ProviderScope(
    overrides: [sessionControllerProvider.overrideWith(controller)],
    child: const MaterialApp(home: OtpVerifyPage()),
  );

  Future<void> enterCode(WidgetTester tester) async {
    final fields = find.byType(OtpDigitField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
      await tester.pump();
    }
  }

  group('OtpVerifyPage submission', () {
    testWidgets('clears the loading indicator when verifyOtp throws', (
      tester,
    ) async {
      await tester.pumpWidget(app(() => _ThrowingController(phone)));

      await enterCode(tester);
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('accepts a second attempt after a throwing verifyOtp', (
      tester,
    ) async {
      final controller = _ThrowingController(phone);
      await tester.pumpWidget(app(() => controller));

      await enterCode(tester);
      await tester.pumpAndSettle();
      // Le garde `_isSubmitting` doit avoir été relâché : sans le
      // `finally`, cette seconde saisie repartirait en `return` immédiat.
      await enterCode(tester);
      await tester.pumpAndSettle();

      expect(controller.attempts, 2);
    });

    testWidgets('names the account collision on device_already_registered', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          () => _ResultController(
            phone,
            const VerifyOtpDeviceAlreadyRegistered(),
          ),
        ),
      );

      await enterCode(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Cet appareil est déjà lié à un autre compte.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('invites a retry on a generic failure', (tester) async {
      await tester.pumpWidget(
        app(() => _ResultController(phone, const VerifyOtpFailure())),
      );

      await enterCode(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Connexion impossible. Vérifie ta connexion et réessaie.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('OtpVerifyPage resend', () {
    testWidgets('surfaces a message instead of throwing', (tester) async {
      await tester.pumpWidget(app(() => _ThrowingController(phone)));

      await tester.tap(find.text('Renvoyer le code'));
      await tester.pumpAndSettle();

      expect(
        find.text('Envoi impossible. Vérifie ta connexion et réessaie.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Reproduit la chaîne cassée : le controller laisse remonter ce que le
/// repository a levé (une `DioException` non mappée, en vrai).
class _ThrowingController extends SessionController {
  _ThrowingController(this._phone);

  final PhoneNumber _phone;
  int attempts = 0;

  @override
  SessionState build() =>
      OtpRequested(phone: _phone, expiresAt: DateTime.utc(2026, 4, 27, 15));

  @override
  Future<VerifyOtpResult> verifyOtp(String rawCode) async {
    attempts += 1;
    throw Exception('unmapped backend error');
  }

  @override
  Future<ResendOtpResult> resendOtp() async {
    throw Exception('network down');
  }
}

/// Controller qui rend un résultat donné, pour vérifier la copie affichée.
class _ResultController extends SessionController {
  _ResultController(this._phone, this._result);

  final PhoneNumber _phone;
  final VerifyOtpResult _result;

  @override
  SessionState build() =>
      OtpRequested(phone: _phone, expiresAt: DateTime.utc(2026, 4, 27, 15));

  @override
  Future<VerifyOtpResult> verifyOtp(String rawCode) async => _result;
}
