import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_usuario/main.dart';

void main() {
  testWidgets('App renders la pantalla inicial sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Transporte Santa Cruz'), findsOneWidget);
  });
}
