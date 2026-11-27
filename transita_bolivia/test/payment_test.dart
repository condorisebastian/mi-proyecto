import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transita_bolivia/models/driver_payment.dart';
import 'package:transita_bolivia/models/trip_qr.dart';
import 'package:transita_bolivia/services/firebase_service.dart';

void main() {
  group('QR de cobro', () {
    test(
      'el monto personalizado conserva el total y valida centavos y cantidad',
      () {
        const qr = TripQr(
          conductorId: 2,
          tipo: TripQr.customType,
          puntos: 7.50,
          reference: 'monto-libre',
          cantidad: 3,
        );
        final parsed = TripQr.tryParse(qr.encode())!;
        expect(parsed.isCustom, isTrue);
        expect(parsed.puntos, 7.50);
        expect(parsed.cantidad, 3);
        for (final value in ['0', '-1', '3.501', '1000000.01', 'NaN']) {
          expect(
            TripQr.tryParse('CONDUCTOR:2:personalizado:$value:libre:1'),
            isNull,
          );
        }
        expect(
          TripQr.tryParse('CONDUCTOR:2:personalizado:7.50:libre:0'),
          isNull,
        );
        expect(
          TripQr.tryParse('CONDUCTOR:2:personalizado:7.50:libre:51'),
          isNull,
        );
      },
    );
    test('codifica un pago grupal y rechaza cantidad o total manipulados', () {
      const qr = TripQr(
        conductorId: 2,
        tipo: 'estudiante',
        puntos: 3,
        reference: 'grupo-3',
        cantidad: 3,
      );
      expect(TripQr.tryParse(qr.encode())?.cantidad, 3);
      expect(TripQr.tryParse('CONDUCTOR:2:estudiante:3:grupo-3:2'), isNull);
      expect(TripQr.tryParse('CONDUCTOR:2:estudiante:1:grupo-3:0'), isNull);
      expect(TripQr.tryParse('CONDUCTOR:2:civil:153:grupo-3:51'), isNull);
    });
    test(
      'conserva conductor, tarifa y referencia sin incluir credenciales',
      () {
        for (final fare in TripQr.fares.entries) {
          final qr = TripQr(
            conductorId: 2,
            tipo: fare.key,
            puntos: fare.value,
            reference: 'viaje-123',
          );
          final parsed = TripQr.tryParse(qr.encode())!;
          expect(parsed.conductorId, 2);
          expect(parsed.tipo, fare.key);
          expect(parsed.puntos, fare.value);
          expect(parsed.reference, 'viaje-123');
        }
      },
    );
    test(
      'rechaza importes manipulados, identificadores y referencias inválidos',
      () {
        for (final raw in [
          'CONDUCTOR:0:estudiante:1:x',
          'CONDUCTOR:-1:estudiante:1:x',
          'CONDUCTOR:2:civil:1:x',
          'CONDUCTOR:2:estudiante:-1:x',
          'CONDUCTOR:2:desconocido:1:x',
          'CONDUCTOR:2:desconocido:0:x:1',
          'CONDUCTOR:2:estudiante:1:../x',
          'CONDUCTOR:2:estudiante:1:',
          'USUARIO:2:estudiante:1:x',
          'CONDUCTOR:2',
        ]) {
          expect(TripQr.tryParse(raw), isNull, reason: raw);
        }
      },
    );
    test('admite los QR anteriores de cuatro campos', () {
      expect(TripQr.tryParse('CONDUCTOR:2:estudiante:1')?.puntos, 1);
    });
  });

  group('Alarmas del conductor', () {
    final since = DateTime.utc(2026, 10, 15, 12);
    DriverPayment payment(String id, int seconds) => DriverPayment(
      documentId: id,
      puntos: 1,
      pasajero: 'Pasajero',
      fecha: since.add(Duration(seconds: seconds)),
    );
    test(
      'no avisa el historial ni la caché; avisa cada pago confirmado una vez',
      () {
        final tracker = DriverPaymentTracker(since: since);
        final old = payment('anterior', -5);
        final current = payment('nuevo', 1);
        expect(tracker.receive([old], fromCache: false), isEmpty);
        expect(tracker.receive([old, current], fromCache: true), isEmpty);
        expect(tracker.receive([old, current], fromCache: false), [current]);
        expect(tracker.receive([old, current], fromCache: false), isEmpty);
      },
    );
    test('no pierde pagos que llegan juntos o durante la conexión inicial', () {
      final tracker = DriverPaymentTracker(since: since);
      final first = payment('primero', 1);
      final second = payment('segundo', 2);
      expect(tracker.receive([second, first], fromCache: false), [
        first,
        second,
      ]);
      expect(tracker.receive([first, second], fromCache: false), isEmpty);
    });
    test(
      'avisa nuevos documentos aunque el reloj del teléfono esté adelantado',
      () {
        final tracker = DriverPaymentTracker(since: since);
        expect(
          tracker.receive([payment('viejo', -20)], fromCache: false),
          isEmpty,
        );
        final current = payment('nuevo', -10);
        expect(tracker.receive([current], fromCache: false), [current]);
      },
    );
  });

  group('Saldo y cobros en Firestore', () {
    late FakeFirebaseFirestore db;
    late FirebaseService service;
    setUp(() async {
      db = FakeFirebaseFirestore();
      service = FirebaseService.forTesting(db);
      await db.collection('usuarios').doc('u-1').set({
        'id': 1,
        'nombre': 'Ana',
        'apellido': 'Perez',
        'tipo': 'estudiante',
        'puntos': 10,
        'estado': 'activo',
      });
      await db.collection('conductores').doc('c-2').set({
        'id': 2,
        'estado': 'activo',
      });
    });
    Future<({bool ok, String message})> pay({
      num points = 1,
      int driver = 2,
      String type = 'estudiante',
      String reference = 'viaje-1',
      int quantity = 1,
    }) => service.pagarViaje(
      userId: 1,
      conductorId: driver,
      puntos: points,
      metodoPago: 'qr',
      tipoUsuario: type,
      paymentReference: reference,
      cantidadPasajeros: quantity,
    );
    Future<num> balance() async =>
        (await db.collection('usuarios').doc('u-1').get()).data()!['puntos']
            as num;

    test(
      'cobra el monto personalizado una sola vez y conserva el tipo del pasajero',
      () async {
        expect(
          (await pay(points: 7.50, type: TripQr.customType, quantity: 3)).ok,
          isTrue,
        );
        expect(await balance(), 2.50);
        expect(
          (await pay(points: 7.50, type: TripQr.customType, quantity: 3)).ok,
          isFalse,
        );
        expect(await balance(), 2.50);
        final payment = (await db.collection('transacciones').get()).docs.single
            .data();
        expect(payment['puntos'], 7.50);
        expect(payment['modalidad_cobro'], 'personalizado');
        expect(payment['tipo_usuario'], 'estudiante');
        final summary = await service.getDailySummary(2);
        expect(summary['total_puntos'], 7.50);
        expect(summary['total_pasajeros'], 3);
      },
    );

    test(
      'el monto personalizado respeta saldo, precisión, cantidad y cuentas activas',
      () async {
        for (final amount in [-1, 0, 3.501, 10.50, 1000000.01]) {
          expect(
            (await pay(points: amount, type: TripQr.customType)).ok,
            isFalse,
          );
        }
        expect((await pay(type: TripQr.customType, quantity: 0)).ok, isFalse);
        expect((await pay(type: TripQr.customType, quantity: 51)).ok, isFalse);
        expect((await pay(type: TripQr.customType, driver: 99)).ok, isFalse);
        await db.collection('usuarios').doc('u-1').update({
          'estado': 'bloqueado',
        });
        expect((await pay(type: TripQr.customType)).ok, isFalse);
        await db.collection('usuarios').doc('u-1').update({'estado': 'activo'});
        await db.collection('conductores').doc('c-2').update({
          'estado': 'bloqueado',
        });
        expect((await pay(type: TripQr.customType)).ok, isFalse);
        expect(await balance(), 10);
        expect((await db.collection('transacciones').get()).docs, isEmpty);
      },
    );

    test(
      'un pasajero paga tres pasajes con un solo descuento y tres personas en el resumen',
      () async {
        expect((await pay(points: 3, quantity: 3)).ok, isTrue);
        expect(await balance(), 7);
        expect((await db.collection('transacciones').get()).docs, hasLength(1));
        final summary = await service.getDailySummary(2);
        expect(summary['total_pasajeros'], 3);
        expect(summary['estudiantes'], 3);
        expect(summary['total_puntos'], 3);
        expect(
          (await service.getDailyHistory(2)).single['cantidad_pasajeros'],
          3,
        );
        expect((await pay(points: 3, quantity: 3)).ok, isFalse);
        expect(await balance(), 7);
      },
    );

    test(
      'descuenta y registra un solo cobro; reescanear no vuelve a descontar',
      () async {
        expect((await pay()).ok, isTrue);
        expect(await balance(), 9);
        expect((await pay()).ok, isFalse);
        expect(await balance(), 9);
        final docs = (await db.collection('transacciones').get()).docs;
        expect(docs, hasLength(1));
        expect(docs.single.data()['id_conductor'], 2);
        expect(docs.single.data()['estado'], 'exitoso');
        expect(docs.single.data()['nombre_pasajero'], 'Ana');
      },
    );
    test('saldo insuficiente no deja cobro ni saldo negativo', () async {
      await db.collection('usuarios').doc('u-1').update({'puntos': 0});
      expect((await pay()).message, 'Saldo insuficiente');
      expect(await balance(), 0);
      expect((await db.collection('transacciones').get()).docs, isEmpty);
    });
    test(
      'rechaza tarifa manipulada, cuenta bloqueada y conductor inexistente',
      () async {
        expect((await pay(points: -1)).ok, isFalse);
        expect((await pay(points: 3, type: 'civil')).ok, isFalse);
        expect((await pay(driver: 99)).ok, isFalse);
        await db.collection('usuarios').doc('u-1').update({
          'estado': 'bloqueado',
        });
        expect((await pay()).ok, isFalse);
        expect(await balance(), 10);
        expect((await db.collection('transacciones').get()).docs, isEmpty);
      },
    );
    test('cada nuevo QR genera un viaje independiente', () async {
      expect((await pay()).ok, isTrue);
      expect((await pay(reference: 'viaje-2')).ok, isTrue);
      expect(await balance(), 8);
      final summary = await service.getDailySummary(2);
      expect(summary['total_pasajeros'], 2);
      expect(summary['total_puntos'], 2);
    });
    test(
      'recarga y saldo se actualizan juntos y se rechazan montos negativos',
      () async {
        await service.recargar(userId: 1, puntos: 5, metodoPago: 'qr_bancario');
        expect(await balance(), 15);
        expect((await db.collection('transacciones').get()).docs, hasLength(1));
        await expectLater(
          service.recargar(userId: 1, puntos: -5, metodoPago: 'qr'),
          throwsArgumentError,
        );
        expect(await balance(), 15);
      },
    );
  });
}
