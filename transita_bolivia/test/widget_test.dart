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

void main() {
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

    await tester.pumpWidget(TransitaBoliviaApp(
        auth: auth, driverAuth: driverAuth, adminAuth: adminAuth));
    await tester.pumpAndSettle();
    expect(find.text('Transita Bolivia'), findsOneWidget);
  });

  testWidgets('PayTripScreen: boton ESCANEAR QR no se desborda en ancho estrecho',
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
  });
}
