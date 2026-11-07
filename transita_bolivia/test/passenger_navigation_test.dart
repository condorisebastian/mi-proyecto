import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transita_bolivia/models/user.dart';
import 'package:transita_bolivia/screens/passenger/home_screen.dart';
import 'package:transita_bolivia/screens/soporte/support_screen.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/financial_chat_service.dart';
import 'package:transita_bolivia/services/firebase_service.dart';
import 'package:transita_bolivia/theme.dart';
import 'package:transita_bolivia/widgets/passenger_navigation_bar.dart';

class PassengerAuth extends AuthService {
  User? user = User(
    id: 42,
    nombre: 'Sebastian',
    apellido: 'Prueba',
    ci: '9876543',
    email: '',
    tipo: 'estudiante',
    puntos: 42.50,
    estado: 'activo',
  );
  int logoutCount = 0;

  @override
  User? get currentUser => user;

  @override
  Future<void> refreshUser() async {}

  @override
  Future<void> logout() async {
    logoutCount++;
    user = null;
    notifyListeners();
  }
}

Future<void> openPassenger(
  WidgetTester tester,
  FakeFirebaseFirestore db,
  PassengerAuth auth, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: MaterialApp(
        theme: buildAppTheme(),
        initialRoute: '/passenger',
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routes: {
          '/': (_) => const Scaffold(body: Center(child: Text('Acceso'))),
          '/passenger': (_) => HomeScreen(
            firebaseService: FirebaseService.forTesting(db),
            financialChatService: FinancialChatService(firestore: db),
          ),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('passenger-tab-$index')));
  await tester.pumpAndSettle();
}

void main() {
  late FakeFirebaseFirestore db;
  late PassengerAuth auth;

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = PassengerAuth();
  });

  testWidgets(
    'Inicio es compacto, reserva la identidad para Perfil y destaca QR/NFC',
    (tester) async {
      await openPassenger(tester, db, auth);
      for (final label in [
        'Inicio',
        'Recargas',
        'QR/NFC',
        'Movimientos',
        'Perfil',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      for (final removed in [
        'Provincias',
        'Mi tarjeta NFC',
        'Cerrar sesión',
        '9876543',
      ]) {
        expect(find.text(removed), findsNothing);
      }
      expect(find.textContaining('ID:'), findsNothing);
      expect(find.byIcon(Icons.accessibility_new), findsNothing);
      expect(find.byTooltip('Contactar al call center'), findsOneWidget);
      final greeting = tester.widget<Text>(
        find.text('Hola, Sebastian Estudiante'),
      );
      expect(greeting.style!.fontSize, lessThan(20));
      final navigation = find.byType(PassengerNavigationBar);
      final qrIcon = tester.widget<Icon>(
        find.descendant(
          of: navigation,
          matching: find.byIcon(Icons.qr_code_scanner),
        ),
      );
      final homeIcon = tester.widget<Icon>(
        find.descendant(
          of: navigation,
          matching: find.byIcon(Icons.home_outlined),
        ),
      );
      expect(qrIcon.size, greaterThan(homeIcon.size!));
      // El chat no se abre ni crea su documento antes de entrar a Recargas.
      expect((await db.collection('chats').get()).docs, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Recargas abre el chat y conserva un borrador al cambiar de sección',
    (tester) async {
      await openPassenger(tester, db, auth);
      await tester.tap(find.text('RECARGAR SALDO'));
      await tester.pumpAndSettle();
      expect(find.text('Chat · Recargas'), findsOneWidget);
      expect(find.text('SOLICITAR RECARGA'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Consultar una recarga');
      await selectTab(tester, 0);
      await selectTab(tester, 1);
      expect(find.text('Consultar una recarga'), findsOneWidget);
      expect(
        (await db.collection('solicitudes_financieras').get()).docs,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('QR/NFC permite volver al escáner y no simula un pago NFC', (
    tester,
  ) async {
    await openPassenger(tester, db, auth);
    await selectTab(tester, 2);
    expect(find.text('ESCANEAR QR DEL CONDUCTOR'), findsOneWidget);
    await tester.tap(find.text('NFC'));
    await tester.pumpAndSettle();
    expect(find.text('Pago con NFC'), findsOneWidget);
    expect(find.textContaining('aún no está habilitado'), findsOneWidget);
    expect(find.text('ESCANEAR QR DEL CONDUCTOR'), findsNothing);
    await selectTab(tester, 0);
    await selectTab(tester, 2);
    expect(find.text('Pago con NFC'), findsOneWidget);
    await tester.tap(find.text('PAGAR CON QR'));
    await tester.pumpAndSettle();
    expect(find.text('ESCANEAR QR DEL CONDUCTOR'), findsOneWidget);
    expect(auth.currentUser!.puntos, 42.50);
    expect((await db.collection('transacciones').get()).docs, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Movimientos muestra viajes y recargas solo del pasajero actual',
    (tester) async {
      for (final entry in [
        (1, 42, 'cobro_viaje'),
        (2, 42, 'recarga'),
        (3, 99, 'recarga'),
      ]) {
        await db.collection('transacciones').doc('${entry.$1}').set({
          'id': entry.$1,
          'id_usuario': entry.$2,
          'id_conductor': 7,
          'tipo': entry.$3,
          'puntos': entry.$2 == 99 ? 999 : 3.50,
          'metodo_pago': 'qr',
          'estado': 'exitoso',
          'fecha': Timestamp.fromDate(DateTime(2026, 11, 7, 10, entry.$1)),
        });
      }
      await openPassenger(tester, db, auth);
      await selectTab(tester, 3);
      expect(find.text('Viaje'), findsOneWidget);
      expect(find.text('Recarga'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
      expect(find.text('Historial'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Perfil reúne ID, carnet y salida; cancelar conserva la sesión', (
    tester,
  ) async {
    await openPassenger(tester, db, auth);
    await selectTab(tester, 4);
    expect(find.text('ID de usuario'), findsOneWidget);
    expect(find.text('#42'), findsOneWidget);
    expect(find.text('Carnet de identidad (CI)'), findsOneWidget);
    expect(find.text('9876543'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(auth.logoutCount, 0);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SALIR'));
    await tester.pumpAndSettle();
    expect(auth.logoutCount, 1);
    expect(find.text('Acceso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el icono del call center abre soporte con la identidad del pasajero',
    (tester) async {
      await openPassenger(tester, db, auth);
      await tester.tap(find.byTooltip('Contactar al call center'));
      await tester.pumpAndSettle();
      expect(find.text('Ayuda y soporte'), findsOneWidget);
      final support = tester.widget<SupportScreen>(find.byType(SupportScreen));
      expect(support.canal, 'pasajero');
      expect(support.id, 42);
      expect(support.nombre, 'Sebastian Prueba');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('las cinco secciones caben en 320 por 568 con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openPassenger(tester, db, auth, textScale: 1.8);
    for (final index in [1, 2, 3, 4, 0]) {
      await selectTab(tester, index);
      expect(tester.takeException(), isNull, reason: 'Sección $index');
    }
    await selectTab(tester, 1);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Enviar mensaje'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
