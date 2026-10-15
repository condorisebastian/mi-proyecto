import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/api_service.dart';
import 'package:transita_bolivia/services/driver_auth_service.dart';
import 'package:transita_bolivia/services/driver_api_service.dart';
import 'package:transita_bolivia/services/admin_auth_service.dart';
import 'package:transita_bolivia/main.dart';
import 'package:transita_bolivia/screens/passenger/pay_trip_screen.dart';
import 'package:transita_bolivia/screens/passenger/recharge_screen.dart';
import 'package:transita_bolivia/screens/driver/charge_screen.dart';
import 'package:transita_bolivia/models/user.dart';

class _PassengerAuth extends AuthService {
  @override
  User get currentUser => User(
    id: 1,
    nombre: 'Ana',
    apellido: 'Perez',
    ci: '',
    email: '',
    tipo: 'estudiante',
    puntos: 10,
    estado: 'activo',
  );
}

void main() {
  testWidgets('Cobrar solo ofrece QR y se adapta a una pantalla estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DriverAuthService(),
        child: const MaterialApp(home: DriverChargeScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('MOSTRAR QR'), findsOneWidget);
    expect(find.textContaining('NFC'), findsNothing);
    expect(find.byIcon(Icons.nfc), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelar una recarga no procesa ni acredita puntos', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>(
        create: (_) => _PassengerAuth(),
        child: const MaterialApp(home: RechargeScreen()),
      ),
    );
    await tester.tap(find.text('Bs 5'));
    await tester.pump();
    await tester.ensureVisible(find.text('RECARGAR PUNTOS'));
    await tester.tap(find.text('RECARGAR PUNTOS'));
    await tester.pumpAndSettle();
    expect(find.text('Recarga de demostración'), findsOneWidget);
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(find.text('Recarga Exitosa'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('10 PUNTOS'), findsOneWidget);
  });

  testWidgets('App renders role selection screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final auth = AuthService();
    await auth.restoreSession();
    ApiService.tokenProvider = () => auth.token;

    final driverAuth = DriverAuthService();
    await driverAuth.restoreSession();
    DriverApiService.tokenProvider = () => driverAuth.token;

    final adminAuth = AdminAuthService();
    await adminAuth.restoreSession();

    await tester.pumpWidget(
      TransitaBoliviaApp(
        auth: auth,
        driverAuth: driverAuth,
        adminAuth: adminAuth,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transita Bolivia'), findsOneWidget);
  });

  testWidgets(
    'PayTripScreen: boton ESCANEAR QR no se desborda en ancho estrecho',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('RenderFlex overflowed')) {
          // ignore: avoid_print
          print('=== DIAGNOSTICO OVERFLOW ===');
          FlutterError.dumpErrorToConsole(details);
          // ignore: avoid_print
          print('=== FIN DIAGNOSTICO ===');
        }
        oldOnError?.call(details);
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
          child: const MaterialApp(home: PayTripScreen()),
        ),
      );
      await tester.pump();
      FlutterError.onError = oldOnError;
      expect(tester.takeException(), isNull);
      expect(find.text('ESCANEAR QR DEL CONDUCTOR'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    },
  );
}
