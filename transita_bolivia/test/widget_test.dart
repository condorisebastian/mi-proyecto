import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/api_service.dart';
import 'package:transita_bolivia/services/driver_auth_service.dart';
import 'package:transita_bolivia/services/driver_api_service.dart';
import 'package:transita_bolivia/main.dart';

void main() {
  testWidgets('App renders role selection screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final auth = AuthService();
    await auth.restoreSession();
    ApiService.tokenProvider = () => auth.token;

    final driverAuth = DriverAuthService();
    await driverAuth.restoreSession();
    DriverApiService.tokenProvider = () => driverAuth.token;

    await tester.pumpWidget(TransitaBoliviaApp(auth: auth, driverAuth: driverAuth));
    await tester.pumpAndSettle();
    expect(find.text('Transita Bolivia'), findsOneWidget);
  });
}
