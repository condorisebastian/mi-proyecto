import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/models/conductor.dart';
import 'package:transita_bolivia/models/user.dart';
import 'package:transita_bolivia/screens/driver/charge_screen.dart';
import 'package:transita_bolivia/screens/driver/home_screen.dart';
import 'package:transita_bolivia/screens/driver/summary_screen.dart';
import 'package:transita_bolivia/screens/passenger/role_selection_screen.dart';
import 'package:transita_bolivia/services/driver_auth_service.dart';
import 'package:transita_bolivia/services/firebase_service.dart';
import 'package:transita_bolivia/services/passenger_qr_window_store.dart';
import 'package:transita_bolivia/theme.dart';
import 'package:transita_bolivia/widgets/brand_logo.dart';

import 'passenger_navigation_test.dart' as fixture;

class TestDriverAuth extends DriverAuthService {
  @override
  Conductor get currentConductor => Conductor(
    id: 7,
    nombre: 'Juan',
    apellido: 'Prueba',
    ci: '',
    licencia: 'Demo',
    estado: 'activo',
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'el plazo de 15 segundos sobrevive a reaperturas y llamadas simultáneas',
    () async {
      var now = DateTime.utc(2026, 11, 25, 12, 0, 0, 500);
      final store = PassengerQrWindowStore(clock: () => now);
      final firstBatch = await Future.wait([store.issue(42), store.issue(42)]);
      final first = firstBatch.first;
      expect(firstBatch.last.qr!.nonce, first.qr!.nonce);
      expect(first.remaining(now), 15);
      now = now.add(const Duration(seconds: 8));
      // Otra instancia representa cerrar la pantalla y restaurar el estado local.
      final restored = PassengerQrWindowStore(clock: () => now);
      final reopened = await restored.issue(42);
      expect(reopened.qr!.nonce, first.qr!.nonce);
      expect(reopened.remaining(now), 7);
      final another = await restored.issue(43);
      expect(another.qr!.userId, 43);
      expect(another.qr!.nonce, isNot(first.qr!.nonce));
      now = first.nextGenerationAt.subtract(const Duration(milliseconds: 1));
      // El formato del QR redondea la caducidad a segundos, pero nunca
      // se adelanta la siguiente generación ni siquiera un milisegundo.
      expect(
        (await restored.issue(42)).nextGenerationAt,
        first.nextGenerationAt,
      );
      expect((await restored.issue(42)).remaining(now), 1);
      now = first.nextGenerationAt;
      final next = await restored.issue(42);
      expect(next.qr!.nonce, isNot(first.qr!.nonce));
      expect(next.remaining(now), 15);
    },
  );

  test('ocultar el QR no permite saltarse el tiempo de espera', () async {
    var now = DateTime.utc(2026, 11, 25, 12);
    final store = PassengerQrWindowStore(clock: () => now);
    final first = await store.issue(42);
    now = now.add(const Duration(seconds: 3));
    await store.hide(42);
    final reopened = await PassengerQrWindowStore(clock: () => now).issue(42);
    expect(reopened.qr, isNull);
    expect(reopened.nextGenerationAt, first.nextGenerationAt);
    expect(reopened.remaining(now), 12);
    now = first.nextGenerationAt;
    expect((await store.issue(42)).qr!.nonce, isNot(first.qr!.nonce));
  });

  for (final type in ['estudiante', 'civil', 'adulto_mayor', 'discapacitado']) {
    testWidgets('$type conserva billetera, foto, menú y QR sin escáner', (
      tester,
    ) async {
      final auth = fixture.PassengerAuth();
      auth.user = User.fromJson({...auth.user!.toJson(), 'tipo': type});
      await fixture.openPassenger(tester, FakeFirebaseFirestore(), auth);
      expect(find.text('Tu billetera'), findsOneWidget);
      for (final label in ['Inicio', 'Mi carnet', 'Pagar', 'Rutas', 'Perfil']) {
        expect(find.text(label), findsOneWidget);
      }
      await fixture.selectTab(tester, 4);
      expect(find.text('Foto de perfil'), findsOneWidget);
      expect(find.textContaining('Biométrica'), findsNothing);
      await fixture.selectTab(tester, 2);
      expect(find.text('Mostrar mi QR'), findsOneWidget);
      expect(find.text('Escanear QR'), findsNothing);
      expect(
        find.text(type == 'civil' ? '3.50 puntos' : '1.00 puntos'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('show-passenger-qr')),
      );
      await tester.tap(find.byKey(const ValueKey('show-passenger-qr')));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      final payload = (await PassengerQrWindowStore.instance.issue(
        42,
      )).qr!.encode();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('regenerate-passenger-qr')),
            )
            .onPressed,
        isNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-passenger-qr')));
      await tester.pumpAndSettle();
      expect(
        (await PassengerQrWindowStore.instance.issue(42)).qr!.encode(),
        payload,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'bienvenida usa el fondo y abre ayuda, cobertura y ambos accesos',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const RoleSelectionScreen(),
          routes: {
            '/passenger/type': (_) => Scaffold(
              appBar: AppBar(),
              body: const Text('Elegir categoría'),
            ),
            '/driver/login': (_) => Scaffold(
              appBar: AppBar(),
              body: const Text('Acceso conductor'),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('¿Cómo usarás Mi Pasaje?'), findsOneWidget);
      expect(find.byType(BrandLogo), findsNothing);
      expect(
        find.image(const AssetImage(RoleSelectionScreen.backgroundAsset)),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.accessibility_new), findsNothing);
      await tester.tap(find.byTooltip('Ayuda'));
      await tester.pumpAndSettle();
      expect(find.text('Te ayudamos a empezar'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ubicación y cobertura'));
      await tester.pumpAndSettle();
      expect(find.text('Santa Cruz de la Sierra'), findsOneWidget);
      await tester.tap(find.text('Consultar rutas'));
      await tester.pumpAndSettle();
      expect(find.text('Rutas'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viajero / Pasajero'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir categoría'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conductor'));
      await tester.pumpAndSettle();
      expect(find.text('Acceso conductor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bienvenida cabe en 320 × 568 con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const RoleSelectionScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Conductor'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'conductor tiene cobro principal, resumen en vivo y las cuatro categorías',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('transacciones').doc('confirmed').set({
        'id_conductor': 7,
        'tipo': 'cobro_viaje',
        'estado': 'exitoso',
        'puntos': 7.0,
        'cantidad_pasajeros': 2,
        'tipo_usuario': 'civil',
        'fecha': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverAuthService>(
          create: (_) => TestDriverAuth(),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: DriverHomeScreen(
              firebaseService: FirebaseService.forTesting(db),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hola, Juan'), findsOneWidget);
      expect(find.text('Bs 7.00'), findsOneWidget);
      expect(find.text('2 pasajes confirmados'), findsOneWidget);
      expect(find.byType(DriverChargeScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('driver-primary-charge')));
      await tester.pumpAndSettle();
      expect(find.byType(DriverChargeScreen), findsOneWidget);
      expect(find.text('Preparar cobro'), findsOneWidget);
      expect(find.text('Bs 3.50 / persona'), findsOneWidget);
      await tester.tap(find.text('Resumen'));
      await tester.pumpAndSettle();
      expect(find.text('Recaudación confirmada'), findsOneWidget);
      expect(find.text('Personas con discapacidad'), findsOneWidget);
      expect(find.text('Compartir resumen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('conductor, cobro y resumen caben con letra grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<DriverAuthService>(
        create: (_) => TestDriverAuth(),
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: DriverHomeScreen(
            firebaseService: FirebaseService.forTesting(
              FakeFirebaseFirestore(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('driver-primary-charge')),
    );
    await tester.tap(find.byKey(const ValueKey('driver-primary-charge')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Cobro');
    await tester.ensureVisible(find.text('Persona con discapacidad'));
    expect(tester.takeException(), isNull, reason: 'Categorías');
    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Compartir resumen'));
    expect(find.byType(DriverSummaryScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Resumen');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
