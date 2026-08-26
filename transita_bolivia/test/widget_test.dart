import 'package:flutter_test/flutter_test.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/api_service.dart';
import 'package:transita_bolivia/main.dart';

void main() {
  testWidgets('App renders role selection screen', (WidgetTester tester) async {
    final auth = AuthService();
    await auth.restoreSession();
    ApiService.tokenProvider = () => auth.token;
    await tester.pumpWidget(TransitaBoliviaApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Transita Bolivia'), findsOneWidget);
  });
}
