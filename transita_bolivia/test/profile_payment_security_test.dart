import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/services/payment_preferences.dart';
import 'package:transita_bolivia/services/app_info.dart';
import 'package:transita_bolivia/screens/passenger/profile_options_screen.dart';
import 'package:transita_bolivia/screens/soporte/support_screen.dart';
import 'package:transita_bolivia/screens/passenger/student_card_screen.dart';
import 'passenger_navigation_test.dart' as fixture;

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
    'otra cuenta no hereda límites y quitar el límite se persiste',
    () async {
      final first = PaymentPreferences(42);
      await first.setLimit(5);
      final other = PaymentPreferences(43);
      await other.load();
      expect(other.limitCents, isNull);
      expect((await PaymentAuthorization(other).authorize(20)).ok, isTrue);
      await first.setLimit(null);
      final restored = PaymentPreferences(42);
      await restored.load();
      expect(restored.limitCents, isNull);
    },
  );

  test(
    'una preferencia biométrica antigua no bloquea pagos ni elimina el límite',
    () async {
      final storage = await SharedPreferences.getInstance();
      await storage.setBool('payments.firebase.42.biometric', true);
      final prefs = PaymentPreferences(42);
      await prefs.setLimit(3.50);
      final authorization = PaymentAuthorization(prefs);
      expect((await authorization.authorize(3.50)).ok, isTrue);
      expect((await authorization.authorize(4)).ok, isFalse);
      expect(storage.containsKey('payments.firebase.42.biometric'), isFalse);
      expect(storage.getInt('payments.firebase.42.limit_cents'), 350);
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

  testWidgets(
    'Versión consulta el paquete instalado mediante el canal de información',
    (tester) async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AppInfo.channel, (call) async {
        calls.add(call.method);
        return {'version': '2.3.0', 'build': '17'};
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(AppInfo.channel, null),
      );
      await tester.pumpWidget(const MaterialApp(home: AppVersionScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Versión 2.3.0'), findsOneWidget);
      expect(find.textContaining('Compilación 17'), findsOneWidget);
      expect(calls, ['appVersion']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Mi carnet abre el nuevo diseño horizontal y restaura la pantalla al cerrar',
    (tester) async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await fixture.openPassenger(
        tester,
        FakeFirebaseFirestore(),
        fixture.PassengerAuth(),
      );
      await fixture.selectTab(tester, 1);
      expect(find.text('Muestra · Datos ficticios'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('student-card-fullscreen-button')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('student-card-fullscreen-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('student-card-fullscreen')),
        findsOneWidget,
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        StudentCardScreen.assetPath,
      );
      expect(image.fit, BoxFit.contain);
      expect(
        calls
            .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
            .last
            .arguments,
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      );
      expect(
        calls
            .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
            .last
            .arguments,
        'SystemUiMode.immersiveSticky',
      );
      await tester.tap(
        find.byKey(const ValueKey('student-card-fullscreen-close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('student-card-fullscreen')),
        findsNothing,
      );
      expect(
        calls
            .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
            .last
            .arguments,
        isEmpty,
      );
      expect(
        calls
            .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
            .last
            .arguments,
        'SystemUiMode.edgeToEdge',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Perfil conserva sus opciones sin biometría y el cambio de clave prepara soporte',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await fixture.openPassenger(tester, db, fixture.PassengerAuth());
      await fixture.selectTab(tester, 4);
      expect(find.text('Biometría digital'), findsNothing);
      expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);
      for (final label in [
        'Mis datos',
        'Foto de perfil',
        'Puntos de atención',
        'Establecer montos límites',
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
      await fixture.selectTab(tester, 4);
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
