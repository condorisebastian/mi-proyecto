import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/models/conductor.dart';
import 'package:transita_bolivia/models/money.dart';
import 'package:transita_bolivia/models/trip_qr.dart';
import 'package:transita_bolivia/screens/driver/charge_screen.dart';
import 'package:transita_bolivia/screens/driver/login_screen.dart';
import 'package:transita_bolivia/screens/passenger/login_screen.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/driver_auth_service.dart';
import 'package:transita_bolivia/services/firebase_service.dart';
import 'package:transita_bolivia/services/login_preferences.dart';

class _Driver extends DriverAuthService {
  @override
  bool get isLoading => true;
  @override
  Conductor get currentConductor => Conductor(
    id: 2,
    nombre: 'Juan',
    apellido: 'Perez',
    ci: '9876543',
    licencia: 'LIC',
    estado: 'activo',
  );
}

class _LoadingPassenger extends AuthService {
  @override
  bool get isLoading => true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('los importes conservan centavos y rechazan precisión inválida', () {
    expect(Money.add(0.10, 0.20), 0.30);
    expect(Money.subtract(10, 3.50), 6.50);
    expect(Money.multiply(3.50, 3), 10.50);
    expect(Money.read('3,50'), 3.50);
    expect(Money.read('6.50'), 6.50);
    expect(Money.format(3.5), '3.50');
    expect(Money.tryParse('3.501'), isNull);
    expect(Money.valid(double.nan), isFalse);
    expect(Money.valid(double.infinity), isFalse);
  });

  test('QR civil individual y grupal usan la tarifa de Bs 3.50', () {
    for (final quantity in [1, 2, 3]) {
      final qr = TripQr(
        conductorId: 2,
        tipo: 'civil',
        puntos: Money.multiply(3.50, quantity),
        reference: 'grupo-$quantity',
        cantidad: quantity,
      );
      final parsed = TripQr.tryParse(qr.encode())!;
      expect(parsed.puntos, 3.50 * quantity);
      expect(parsed.cantidad, quantity);
    }
    expect(TripQr.tryParse('CONDUCTOR:2:civil:3:viejo:1'), isNull);
    expect(TripQr.tryParse('CONDUCTOR:2:civil:10.49:alterado:3'), isNull);
    expect(TripQr.fares['estudiante'], 1);
    expect(TripQr.fares['adulto_mayor'], 1);
    expect(TripQr.fares['discapacitado'], 1);
  });

  group('pagos con centavos', () {
    late FakeFirebaseFirestore db;
    late FirebaseService service;
    setUp(() async {
      db = FakeFirebaseFirestore();
      service = FirebaseService.forTesting(db);
      await db.collection('usuarios').doc('u-1').set({
        'id': 1,
        'nombre': 'Maria',
        'apellido': 'Garcia',
        'tipo': 'civil',
        'puntos': 10.50,
        'estado': 'activo',
      });
      await db.collection('conductores').doc('c-2').set({
        'id': 2,
        'estado': 'activo',
      });
    });
    Future<({bool ok, String message})> pay(
      num amount,
      String reference, [
      int quantity = 1,
    ]) => service.pagarViaje(
      userId: 1,
      conductorId: 2,
      puntos: amount,
      metodoPago: 'qr',
      tipoUsuario: 'civil',
      paymentReference: reference,
      cantidadPasajeros: quantity,
    );
    Future<num> balance() async =>
        (await db.collection('usuarios').doc('u-1').get()).data()!['puntos']
            as num;

    test(
      'descuenta 3.50 una sola vez y conserva el saldo fraccionario',
      () async {
        await db.collection('usuarios').doc('u-1').update({'puntos': 10});
        expect((await pay(3.50, 'civil')).ok, isTrue);
        expect(await balance(), 6.50);
        expect((await service.fetchUserById(1))!.puntos, 6.50);
        expect((await pay(3.50, 'civil')).ok, isFalse);
        expect(await balance(), 6.50);
        expect(
          (await db.collection('transacciones').get()).docs.single
              .data()['puntos'],
          3.50,
        );
      },
    );
    test('tres civiles pagan 10.50 y figuran como tres pasajeros', () async {
      expect((await pay(10.50, 'grupo', 3)).ok, isTrue);
      expect(await balance(), 0);
      final summary = await service.getDailySummary(2);
      expect(summary['total_puntos'], 10.50);
      expect(summary['total_pasajeros'], 3);
      expect(summary['civiles'], 3);
    });
    test(
      'rechaza saldo insuficiente y montos con fracciones menores al centavo',
      () async {
        await db.collection('usuarios').doc('u-1').update({'puntos': 3});
        expect((await pay(3.50, 'sin-saldo')).ok, isFalse);
        expect((await pay(3.501, 'precision')).ok, isFalse);
        expect(await balance(), 3);
        expect((await db.collection('transacciones').get()).docs, isEmpty);
        await service.recargar(userId: 1, puntos: 0.50, metodoPago: 'chat');
        expect((await pay(3.50, 'recargado')).ok, isTrue);
        expect(await balance(), 0);
      },
    );
  });

  testWidgets('tocar Civil abre automáticamente el QR de tres pasajes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<DriverAuthService>.value(
        value: _Driver(),
        child: const MaterialApp(home: DriverChargeScreen()),
      ),
    );
    await tester.tap(find.byTooltip('Agregar un pasaje'));
    await tester.pump();
    await tester.tap(find.byTooltip('Agregar un pasaje'));
    await tester.pump();
    await tester.ensureVisible(find.text('Civil'));
    await tester.tap(find.text('Civil'));
    await tester.pumpAndSettle();
    expect(find.text('MOSTRAR QR'), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    final qrSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere(
          (widget) =>
              widget.properties.label?.startsWith('QR de cobro: ') == true,
        );
    final parsed = TripQr.tryParse(
      qrSemantics.properties.label!.substring('QR de cobro: '.length),
    )!;
    expect(parsed.tipo, 'civil');
    expect(parsed.cantidad, 3);
    expect(parsed.puntos, 10.50);
    expect(find.textContaining('Total: Bs 10.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('recuerda el carnet por perfil sin guardar el PIN', () async {
    expect(await LoginPreferences.readCi('conductor'), '9876543');
    await LoginPreferences.saveCi('conductor', '1111111');
    expect(await LoginPreferences.readCi('conductor'), '1111111');
    expect(await LoginPreferences.readCi('estudiante'), '1234567');
  });

  testWidgets(
    'el acceso de pasajero precarga el CI y mantiene la carga circular',
    (tester) async {
      await LoginPreferences.saveCi('estudiante', '2222222');
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: _LoadingPassenger(),
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '2222222',
      );
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(22, 22),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el acceso de conductor precarga el CI y mantiene la carga circular',
    (tester) async {
      await LoginPreferences.saveCi('conductor', '3333333');
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverAuthService>.value(
          value: _Driver(),
          child: const MaterialApp(home: DriverLoginScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '3333333',
      );
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(22, 22),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
