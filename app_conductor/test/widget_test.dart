import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductor/main.dart';

void main() {
  testWidgets('Muestra la pantalla de inicio de sesión al arrancar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Panel Conductor'), findsOneWidget);
    expect(find.text('Nro. Licencia'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });

  testWidgets('Muestra error al enviar el formulario vacío',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese su licencia'), findsOneWidget);
    expect(find.text('Ingrese su contraseña'), findsOneWidget);
  });
}
