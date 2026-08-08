import 'package:flutter_test/flutter_test.dart';

import 'package:app_usuario/main.dart';

void main() {
  testWidgets('Muestra la selección de tipo de usuario al arrancar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Transporte Santa Cruz'), findsOneWidget);
    expect(find.text('¿Quién eres?'), findsOneWidget);
    expect(find.text('Estudiante'), findsOneWidget);
    expect(find.text('Civil'), findsOneWidget);
    expect(find.text('Adulto Mayor'), findsOneWidget);
  });

  testWidgets('Navega al login al elegir tipo de usuario',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Estudiante'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Cédula de Identidad'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
  });
}
