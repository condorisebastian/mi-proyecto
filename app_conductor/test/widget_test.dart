import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductor/main.dart';
import 'package:app_conductor/services/auth_service.dart';

void main() {
  testWidgets('App renders la pantalla inicial sin errores',
      (WidgetTester tester) async {
    final auth = AuthService();
    await tester.pumpWidget(MyApp(auth: auth));
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Transporte Santa Cruz'), findsOneWidget);
  });
}
