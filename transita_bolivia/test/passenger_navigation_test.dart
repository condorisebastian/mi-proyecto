import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/models/user.dart';
import 'package:transita_bolivia/screens/passenger/home_screen.dart';
import 'package:transita_bolivia/screens/passenger/receipt_screen.dart';
import 'package:transita_bolivia/services/app_preferences.dart';
import 'package:transita_bolivia/screens/soporte/support_screen.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/financial_chat_service.dart';
import 'package:transita_bolivia/services/firebase_service.dart';
import 'package:transita_bolivia/theme.dart';
import 'package:transita_bolivia/widgets/passenger_navigation_bar.dart';
import 'package:transita_bolivia/widgets/passenger_wallet_card.dart';
import 'package:transita_bolivia/widgets/amount_speaker_button.dart';

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
  AppPreferences? preferences,
}) async {
  final settings = preferences ?? AppPreferences();
  await settings.load();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: MaterialApp(
        theme: buildAppTheme(),
        initialRoute: '/passenger',
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        routes: {
          '/': (_) => const Scaffold(body: Center(child: Text('Acceso'))),
          '/passenger': (_) => HomeScreen(
            firebaseService: FirebaseService.forTesting(db),
            financialChatService: FinancialChatService(firestore: db),
            preferences: settings,
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
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    auth = PassengerAuth();
  });

  testWidgets(
    'Inicio muestra billetera y Descubre más, con Pagar principal y Mi carnet en la barra',
    (tester) async {
      await openPassenger(tester, db, auth);
      for (final label in ['Inicio', 'Mi carnet', 'Pagar', 'Rutas', 'Perfil']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final removed in [
        'Provincias',
        'Mi tarjeta NFC',
        'Cerrar sesión',
        '9876543',
        'Recargas',
        'Movimientos',
        'RECARGAR SALDO',
        'TUS PUNTOS',
        'Elige tu ciudad',
      ]) {
        expect(find.text(removed), findsNothing);
      }
      expect(find.textContaining('ID:'), findsNothing);
      expect(find.byKey(const ValueKey('change-city')), findsNothing);
      expect(find.text('Tu billetera'), findsOneWidget);
      expect(find.text('Descubre más'), findsOneWidget);
      expect(find.byIcon(Icons.accessibility_new), findsNothing);
      expect(find.byTooltip('Contactar al call center'), findsOneWidget);
      final greeting = tester.widget<Text>(
        find.text('Hola, Sebastian Estudiante'),
      );
      expect(greeting.style!.fontSize, lessThan(20));
      final navigation = find.byType(PassengerNavigationBar);
      final payIcon = tester.widget<Image>(
        find.descendant(
          of: navigation,
          matching: find.byKey(const ValueKey('passenger-pay-icon')),
        ),
      );
      final homeIcon = tester.widget<Icon>(
        find.descendant(
          of: navigation,
          matching: find.byIcon(Icons.home_outlined),
        ),
      );
      expect(
        (payIcon.image as AssetImage).assetName,
        PassengerNavigationBar.payIconAsset,
      );
      expect(payIcon.width, greaterThan(homeIcon.size!));
      expect(
        tester.getCenter(find.byKey(const ValueKey('passenger-tab-2'))).dx,
        closeTo(tester.getCenter(navigation).dx, 0.01),
      );
      // Mostrar las ilustraciones no crea solicitudes ni abre el chat.
      expect((await db.collection('chats').get()).docs, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'los iconos de billetera forman una columna y el ojo sigue a la derecha del saldo',
    (tester) async {
      await openPassenger(tester, db, auth);
      final title = tester.getCenter(
        find.byKey(const ValueKey('wallet-title-icon')),
      );
      final points = tester.getCenter(
        find.byKey(const ValueKey('wallet-points-icon')),
      );
      final history = tester.getCenter(
        find.byKey(const ValueKey('wallet-history-icon')),
      );
      final eye = tester.getCenter(
        find.byKey(const ValueKey('wallet-eye-icon')),
      );
      expect(title.dx, closeTo(points.dx, 0.01));
      expect(history.dx, closeTo(points.dx, 0.01));
      expect(eye.dy, closeTo(points.dy, 0.01));
      expect(eye.dx, greaterThan(tester.getRect(find.text('42.50')).right));
      await tester.tap(find.byTooltip('Ocultar saldo'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(const ValueKey('wallet-eye-icon'))),
        eye,
      );
      expect(find.byTooltip('Mostrar saldo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Rutas permite buscar destinos sin iniciar un cobro', (
    tester,
  ) async {
    await openPassenger(tester, db, auth);
    await selectTab(tester, 3);
    await tester.enterText(find.byType(TextField), 'Cotoca');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Card, 'Cotoca'), findsOneWidget);
    expect(find.text('La Guardia'), findsNothing);
    expect(find.text('Tarifa por verificar'), findsOneWidget);
    expect(find.text('MOSTRAR QR'), findsNothing);
    expect(find.text('COBRAR CON TARJETA'), findsNothing);
    expect((await db.collection('transacciones').get()).docs, isEmpty);
    await selectTab(tester, 0);
    await selectTab(tester, 3);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Cotoca',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la imagen Recárgate puntos abre el chat y conserva el borrador al volver',
    (tester) async {
      await openPassenger(tester, db, auth);
      await tester.ensureVisible(find.byKey(const ValueKey('discover-self')));
      await tester.tap(find.byKey(const ValueKey('discover-self')));
      await tester.pumpAndSettle();
      expect(find.text('Chat · Recargas'), findsOneWidget);
      expect(find.text('SOLICITAR RECARGA'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Consultar una recarga');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('discover-self')));
      await tester.tap(find.byKey(const ValueKey('discover-self')));
      await tester.pumpAndSettle();
      expect(find.text('Consultar una recarga'), findsOneWidget);
      expect(
        (await db.collection('solicitudes_financieras').get()).docs,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ocultar saldo quita importes y lectura de voz y conserva la preferencia',
    (tester) async {
      final settings = AppPreferences();
      await openPassenger(tester, db, auth, preferences: settings);
      final wallet = find.byType(PassengerWalletCard);
      expect(
        find.descendant(of: wallet, matching: find.text('42.50')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Ocultar saldo'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: wallet, matching: find.textContaining('42.50')),
        findsNothing,
      );
      expect(
        find.descendant(of: wallet, matching: find.byType(AmountSpeakerButton)),
        findsNothing,
      );
      expect(settings.balanceHidden, isTrue);
      final restored = AppPreferences();
      await restored.load();
      expect(restored.balanceHidden, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await openPassenger(tester, db, auth, preferences: restored);
      expect(find.byTooltip('Mostrar saldo'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PassengerWalletCard),
          matching: find.textContaining('42.50'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Ver movimientos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('42.50'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mostrar saldo'));
      await tester.pumpAndSettle();
      expect(restored.balanceHidden, isFalse);
      expect(
        find.descendant(
          of: find.byType(PassengerWalletCard),
          matching: find.text('42.50'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recargar a otra persona prepara un mensaje sin crear una recarga para el dueño',
    (tester) async {
      await openPassenger(tester, db, auth);
      final carousel = find.byKey(const ValueKey('discover-carousel'));
      await tester.ensureVisible(carousel);
      await tester.drag(carousel, const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover-another')));
      await tester.pumpAndSettle();
      expect(find.text('Recarga a otra persona'), findsOneWidget);
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.controller!.text, contains('ID del beneficiario:'));
      expect(find.text('SOLICITAR RECARGA'), findsNothing);
      expect(
        (await db.collection('solicitudes_financieras').get()).docs,
        isEmpty,
      );
      expect((await db.collection('transacciones').get()).docs, isEmpty);
      expect(auth.currentUser!.puntos, 42.50);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un movimiento pendiente no genera un comprobante confirmado', (
    tester,
  ) async {
    await db.collection('transacciones').doc('pending').set({
      'id': 11,
      'id_usuario': 42,
      'id_conductor': 7,
      'tipo': 'cobro_viaje',
      'puntos': 1,
      'metodo_pago': 'qr',
      'estado': 'pendiente',
      'fecha': Timestamp.fromDate(DateTime(2026, 11, 7)),
    });
    await openPassenger(tester, db, auth);
    await tester.tap(find.text('Ver movimientos'));
    await tester.pumpAndSettle();
    final movement = find.byKey(const ValueKey('movement-11'));
    await tester.ensureVisible(movement);
    await tester.tap(movement);
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptScreen), findsNothing);
    expect(
      find.textContaining('cuando se confirme el movimiento'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tocar un viaje reciente también abre el comprobante registrado',
    (tester) async {
      await db.collection('transacciones').doc('trip').set({
        'id': 12,
        'id_usuario': 42,
        'id_conductor': 7,
        'tipo': 'cobro_viaje',
        'puntos': 1,
        'metodo_pago': 'qr',
        'estado': 'exitoso',
        'fecha': Timestamp.fromDate(DateTime(2026, 11, 7)),
      });
      await openPassenger(tester, db, auth);
      final trip = find.byKey(const ValueKey('recent-trip-12'));
      await tester.ensureVisible(trip);
      await tester.tap(trip);
      await tester.pumpAndSettle();
      final receipt = tester.widget<ReceiptScreen>(find.byType(ReceiptScreen));
      expect(receipt.receipt.reference, '12');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QR y tarjeta NFC son accesos distintos y NFC no simula un cobro',
    (tester) async {
      await openPassenger(tester, db, auth);
      await selectTab(tester, 2);
      expect(find.text('Mostrar mi QR'), findsOneWidget);
      expect(find.text('Escanear QR'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pay-method-card')));
      await tester.pumpAndSettle();
      expect(find.text('Pago con NFC'), findsOneWidget);
      expect(find.byKey(const ValueKey('nfc-card-preview')), findsOneWidget);
      expect(find.text('Vista previa · Sin activar'), findsOneWidget);
      expect(find.textContaining('aún no está habilitado'), findsOneWidget);
      expect(find.textContaining('42.50'), findsNothing);
      expect(find.textContaining('9876543'), findsNothing);
      expect(find.text('Escanear QR'), findsNothing);
      await selectTab(tester, 0);
      await selectTab(tester, 2);
      expect(find.text('Pago con NFC'), findsOneWidget);
      await tester.ensureVisible(find.text('Ir a QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ir a QR'));
      await tester.pumpAndSettle();
      expect(find.text('Mostrar mi QR'), findsOneWidget);
      expect(auth.currentUser!.puntos, 42.50);
      expect((await db.collection('transacciones').get()).docs, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'la billetera abre el historial propio y tocar una recarga abre su comprobante',
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
      await tester.tap(find.text('Ver movimientos'));
      await tester.pumpAndSettle();
      expect(find.text('Viaje'), findsOneWidget);
      expect(find.text('Recarga'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
      expect(find.text('Historial'), findsNothing);
      final movement = find.byKey(const ValueKey('movement-2'));
      await tester.ensureVisible(movement);
      await tester.tap(movement);
      await tester.pumpAndSettle();
      final receipt = tester.widget<ReceiptScreen>(find.byType(ReceiptScreen));
      expect(receipt.receipt.reference, '2');
      expect(receipt.receipt.amount, 'Bs 3.50');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Perfil reúne ID, carnet y salida; cancelar conserva la sesión', (
    tester,
  ) async {
    await openPassenger(tester, db, auth);
    await selectTab(tester, 4);
    await tester.tap(find.text('Mis datos'));
    await tester.pumpAndSettle();
    expect(find.text('ID de usuario'), findsOneWidget);
    expect(find.text('#42'), findsOneWidget);
    expect(find.text('Carnet de identidad (CI)'), findsOneWidget);
    expect(find.text('9876543'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-logout')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
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
      await tester.pageBack();
      await tester.pumpAndSettle();
      await selectTab(tester, 2);
      await tester.tap(find.byKey(const ValueKey('pay-method-card')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('nfc-support')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nfc-support')));
      await tester.pumpAndSettle();
      final nfcSupport = tester.widget<SupportScreen>(
        find.byType(SupportScreen),
      );
      expect(nfcSupport.canal, 'pasajero');
      expect(nfcSupport.id, 42);
      expect(nfcSupport.nombre, 'Sebastian Prueba');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'billetera, imágenes y pagos caben en 320 por 568 con texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openPassenger(tester, db, auth, textScale: 1.8);
      for (final index in [1, 2, 3, 4, 0]) {
        await selectTab(tester, index);
        expect(tester.takeException(), isNull, reason: 'Sección $index');
      }
      await selectTab(tester, 2);
      await tester.tap(find.byKey(const ValueKey('pay-method-card')));
      await tester.pumpAndSettle();
      final cardGuide = find.text('Cómo funcionará tu tarjeta');
      await tester.ensureVisible(cardGuide);
      await tester.tap(cardGuide);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('3. Acerca tu tarjeta'));
      expect(tester.takeException(), isNull, reason: 'Guía NFC ampliada');
      await selectTab(tester, 0);
      await tester.ensureVisible(find.byKey(const ValueKey('discover-self')));
      await tester.tap(find.byKey(const ValueKey('discover-self')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Enviar mensaje'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
