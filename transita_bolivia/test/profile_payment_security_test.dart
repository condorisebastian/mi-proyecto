import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/services/payment_preferences.dart';
import 'package:transita_bolivia/screens/soporte/support_screen.dart';
import 'package:transita_bolivia/screens/passenger/student_card_screen.dart';
import 'passenger_navigation_test.dart' as fixture;

class _Biometrics extends PaymentBiometrics {
  _Biometrics(this.result);
  final bool result;
  int calls = 0;
  @override
  Future<bool> confirm() async {
    calls++;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'el límite conserva centavos, permite el máximo exacto y bloquea grupos superiores',
    () async {
      final prefs = PaymentPreferences(42);
      await prefs.setLimit(3.50);
      final authorization = PaymentAuthorization(prefs);
      expect((await authorization.authorize(3.50)).ok, isTrue);
      expect((await authorization.authorize(3.51)).ok, isFalse);
      expect((await authorization.authorize(10.50)).ok, isFalse);
      final restored = PaymentPreferences(42);
      await restored.load();
      expect(restored.limitCents, 350);
      for (final invalid in [0, -1, 3.501, double.nan, double.infinity]) {
        expect(() => prefs.setLimit(invalid), throwsArgumentError);
        expect((await authorization.authorize(invalid)).ok, isFalse);
      }
    },
  );

  test(
    'otra cuenta no hereda límites ni biometría y quitar el límite se persiste',
    () async {
      final first = PaymentPreferences(42);
      await first.setLimit(5);
      await first.setBiometric(true);
      final other = PaymentPreferences(43);
      await other.load();
      expect(other.limitCents, isNull);
      expect(other.biometricEnabled, isFalse);
      expect((await PaymentAuthorization(other).authorize(20)).ok, isTrue);
      await first.setLimit(null);
      final restored = PaymentPreferences(42);
      await restored.load();
      expect(restored.limitCents, isNull);
      expect(restored.biometricEnabled, isTrue);
    },
  );

  test(
    'biometría cancelada bloquea el pago y una confirmación permite continuar',
    () async {
      final prefs = PaymentPreferences(42);
      await prefs.setBiometric(true);
      final denied = _Biometrics(false);
      expect(
        (await PaymentAuthorization(
          prefs,
          biometrics: denied,
        ).authorize(3.5)).ok,
        isFalse,
      );
      expect(denied.calls, 1);
      final accepted = _Biometrics(true);
      expect(
        (await PaymentAuthorization(
          prefs,
          biometrics: accepted,
        ).authorize(3.5)).ok,
        isTrue,
      );
      expect(accepted.calls, 1);
      await prefs.setBiometric(false);
      expect(
        (await PaymentAuthorization(
          prefs,
          biometrics: denied,
        ).authorize(3.5)).ok,
        isTrue,
      );
      expect(denied.calls, 1);
    },
  );

  test('un control almacenado inválido no se ignora al autorizar', () async {
    final storage = await SharedPreferences.getInstance();
    await storage.setInt('payments.firebase.42.limit_cents', -1);
    expect(
      (await PaymentAuthorization(PaymentPreferences(42)).authorize(3.5)).ok,
      isFalse,
    );
  });

  test(
    'la verificación biométrica usa la respuesta del sistema y cancela ante error',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        PaymentBiometrics.channel,
        (call) async => call.method == 'biometricAvailable',
      );
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(PaymentBiometrics.channel, null),
      );
      final biometrics = PaymentBiometrics();
      expect(await biometrics.available(), isTrue);
      expect(await biometrics.confirm(), isFalse);
      messenger.setMockMethodCallHandler(
        PaymentBiometrics.channel,
        (_) async => throw PlatformException(code: 'CANCELLED'),
      );
      expect(await biometrics.confirm(), isFalse);
    },
  );

  testWidgets(
    'Mi carnet conserva la marca de muestra y permite ampliar la imagen',
    (tester) async {
      await fixture.openPassenger(
        tester,
        FakeFirebaseFirestore(),
        fixture.PassengerAuth(),
      );
      await fixture.selectTab(tester, 1);
      expect(find.text('Muestra · Datos ficticios'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('student-card-image')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('student-card-image')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        StudentCardScreen.assetPath,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Perfil contiene las nueve opciones y el cambio de clave abre soporte con borrador sin enviarlo',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await fixture.openPassenger(tester, db, fixture.PassengerAuth());
      await fixture.selectTab(tester, 3);
      for (final label in [
        'Mis datos',
        'Puntos de atención',
        'Establecer montos límites',
        'Biometría digital',
        'Cambiar mi clave',
        'Versión de la app',
        'Términos y condiciones',
        'Política de privacidad',
        'Cerrar sesión',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(label), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.text('Cambiar mi clave'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Cambiar mi clave'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Solicitar cambio de clave'));
      await tester.tap(find.text('Solicitar cambio de clave'));
      await tester.pumpAndSettle();
      final support = tester.widget<SupportScreen>(find.byType(SupportScreen));
      expect(support.id, 42);
      expect(support.initialType, 'pin');
      expect(find.textContaining('Solicito cambiar mi PIN'), findsOneWidget);
      expect((await db.collection('incidencias').get()).docs, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guardar un límite desde Perfil se aplica a la autorización del siguiente pago',
    (tester) async {
      await fixture.openPassenger(
        tester,
        FakeFirebaseFirestore(),
        fixture.PassengerAuth(),
      );
      await fixture.selectTab(tester, 3);
      await tester.ensureVisible(find.text('Establecer montos límites'));
      await tester.tap(find.text('Establecer montos límites'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payment-limit-amount')),
        '8.50',
      );
      await tester.ensureVisible(find.text('Guardar límite'));
      await tester.tap(find.text('Guardar límite'));
      await tester.pumpAndSettle();
      final authorization = PaymentAuthorization(PaymentPreferences(42));
      expect((await authorization.authorize(8.50)).ok, isTrue);
      expect((await authorization.authorize(9)).ok, isFalse);
    },
  );
}
