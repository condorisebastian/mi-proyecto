import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/data/province_routes.dart';
import 'package:transita_bolivia/main.dart';
import 'package:transita_bolivia/models/payment_receipt.dart';
import 'package:transita_bolivia/models/transaction.dart';
import 'package:transita_bolivia/screens/accessibility_screen.dart';
import 'package:transita_bolivia/screens/passenger/receipt_screen.dart';
import 'package:transita_bolivia/screens/province_routes_screen.dart';
import 'package:transita_bolivia/services/admin_auth_service.dart';
import 'package:transita_bolivia/services/amount_speech.dart';
import 'package:transita_bolivia/services/app_preferences.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/driver_auth_service.dart';
import 'package:transita_bolivia/theme.dart';

Transaction trip({
  String state = 'exitoso',
  bool pending = false,
  num amount = 10.50,
  String type = 'cobro_viaje',
  int id = -98765,
}) => Transaction(
  id: id,
  idUsuario: 918273,
  idConductor: 2,
  puntos: amount,
  tipo: type,
  metodoPago: 'qr',
  estado: state,
  fecha: DateTime(2026, 10, 29, 10, 15),
  cantidadPasajeros: 3,
  hasPendingWrites: pending,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'ajustes y favoritos sobreviven al recrear el servicio y no pierden cambios concurrentes',
    () async {
      final store = await SharedPreferences.getInstance();
      final preferences = AppPreferences(store);
      await preferences.load();
      await Future.wait([
        preferences.setLargeText(true),
        preferences.setHighContrast(true),
        preferences.setReadAmounts(true),
        preferences.toggleFavorite(provinceRoutes[0].id),
        preferences.toggleFavorite(provinceRoutes[1].id),
      ]);
      final restored = AppPreferences(store);
      await restored.load();
      expect(
        restored.largeText && restored.highContrast && restored.readAmounts,
        isTrue,
      );
      expect(restored.favorites, {provinceRoutes[0].id, provinceRoutes[1].id});
      await restored.toggleFavorite(provinceRoutes[0].id);
      expect(restored.favorites, {provinceRoutes[1].id});
    },
  );

  test(
    'el catálogo descarta favoritos inexistentes y no permite guardarlos',
    () async {
      SharedPreferences.setMockInitialValues({
        'routes.favorites.v1': ['no-existe', provinceRoutes[0].id],
      });
      final preferences = AppPreferences();
      await preferences.load();
      expect(preferences.favorites, {provinceRoutes[0].id});
      await expectLater(
        preferences.toggleFavorite('no-existe'),
        throwsArgumentError,
      );
      await preferences.toggleFavorite(provinceRoutes[1].id);
      expect(preferences.favorites.length, 2);
    },
  );

  test('la voz conserva bolivianos y centavos exactos', () {
    expect(
      AmountSpeech.describe(3.50),
      'Importe: 3 bolivianos con 50 centavos.',
    );
    expect(AmountSpeech.describe(1), 'Importe: 1 boliviano.');
    expect(
      AmountSpeech.describe(0.50, label: 'Saldo'),
      'Saldo: 0 bolivianos con 50 centavos.',
    );
    expect(() => AmountSpeech.describe(-1), throwsArgumentError);
    expect(() => AmountSpeech.describe(double.nan), throwsArgumentError);
  });

  test(
    'no se exportan pagos pendientes, rechazados ni escrituras sin confirmar',
    () {
      for (final transaction in [
        trip(state: 'pendiente'),
        trip(state: 'fallido'),
        trip(pending: true),
        trip(amount: 0),
        trip(id: 0),
      ]) {
        expect(PaymentReceipt.fromTransaction(transaction), isNull);
      }
      expect(
        PaymentReceipt.fromTransaction(trip(state: 'exitosa', type: 'recarga')),
        isNotNull,
      );
    },
  );

  test(
    'el comprobante conserva el total grupal sin multiplicarlo y no incluye la identidad del pasajero',
    () {
      final receipt = PaymentReceipt.fromTransaction(trip())!;
      expect(receipt.amount, 'Bs 10.50');
      expect(receipt.details['Pasajes'], '3');
      expect(receipt.details['Operación'], '-98765');
      expect(receipt.text, contains('Confirmado'));
      expect(receipt.text, isNot(contains('918273')));
      expect(receipt.details.keys, isNot(contains('Saldo')));
    },
  );

  testWidgets(
    'Provincias permite guardar, filtrar y quitar favoritos sin habilitar cobros pendientes',
    (tester) async {
      final preferences = AppPreferences();
      await preferences.load();
      final route = provinceRoutes.first;
      await tester.pumpWidget(
        MaterialApp(
          home: ProvinceRoutesScreen(conductorId: 2, preferences: preferences),
        ),
      );
      await tester.tap(find.byKey(ValueKey('favorite-${route.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoritos (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsOneWidget);
      expect(find.text(route.destination), findsOneWidget);
      expect(find.text('Tarifa por verificar'), findsOneWidget);
      expect(find.text('MOSTRAR QR'), findsNothing);
      await tester.tap(find.byKey(ValueKey('favorite-${route.id}')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Todavía no tienes favoritos'),
        findsOneWidget,
      );
      expect(find.byType(Card), findsNothing);
    },
  );

  testWidgets(
    'accesibilidad y comprobante caben con texto ampliado en pantalla pequeña',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final preferences = AppPreferences();
      await preferences.load();
      Widget wrap(Widget screen) => MaterialApp(
        theme: buildAppTheme(highContrast: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: screen,
      );
      await tester.pumpWidget(
        wrap(AccessibilityScreen(preferences: preferences)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        wrap(ReceiptScreen(receipt: PaymentReceipt.fromTransaction(trip())!)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Bs 10.50'), findsOneWidget);
      await tester.ensureVisible(find.text('Copiar datos'));
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.tap(find.text('Copiar datos'));
      await tester.pumpAndSettle();
      expect(copied, contains('Bs 10.50'));
      expect(find.text('Datos del comprobante copiados.'), findsOneWidget);
    },
  );

  testWidgets(
    'el ajuste de texto respeta tamaños mayores del sistema y mantiene accesible la selección de rol',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final preferences = AppPreferences.instance;
      await preferences.load();
      await preferences.setLargeText(true);
      await preferences.setHighContrast(true);
      addTearDown(() async {
        await preferences.setLargeText(false);
        await preferences.setHighContrast(false);
      });
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: TransitaBoliviaApp(
            auth: AuthService(),
            driverAuth: DriverAuthService(),
            adminAuth: AdminAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final titleContext = tester.element(find.text('Transita Bolivia'));
      expect(
        MediaQuery.textScalerOf(titleContext).scale(10),
        greaterThanOrEqualTo(18),
      );
      expect(Theme.of(titleContext).colorScheme.primary, AppColors.primaryDark);
      await tester.ensureVisible(find.text('Accesibilidad'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'el motor de voz selecciona español y comunica fallos sin arrojar excepciones',
    () async {
      final spoken = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
            call,
          ) async {
            if (call.method == 'isLanguageAvailable') return true;
            if (call.method == 'speak') {
              final args = call.arguments;
              spoken.add(args is Map ? args['text'] as String : args as String);
            }
            return 1;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null),
      );
      final speech = AmountSpeech();
      expect(await speech.speak(3.50), isTrue);
      expect(spoken.single, contains('50 centavos'));
      await speech.stop();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
            call,
          ) async {
            throw PlatformException(code: 'tts_unavailable');
          });
      expect(await speech.speak(0.50), isFalse);
    },
  );
}
