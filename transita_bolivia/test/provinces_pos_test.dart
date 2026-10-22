import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transita_bolivia/data/province_routes.dart';
import 'package:transita_bolivia/models/trip_qr.dart';
import 'package:transita_bolivia/screens/province_routes_screen.dart';
import 'package:transita_bolivia/screens/driver/pos_screen.dart';
import 'package:transita_bolivia/services/driver_auth_service.dart';
import 'package:transita_bolivia/services/firebase_service.dart';
import 'package:transita_bolivia/services/pos_service.dart';

void main() {
  test('Flutter y el servidor comparten todas las rutas y precios', () {
    final json =
        jsonDecode(File('../shared/province_routes.json').readAsStringSync())
            as Map<String, dynamic>;
    final rows = json['routes'] as List;
    expect(provinceRoutes.length, rows.length);
    expect(provinceRoutes.map((r) => r.province).toSet().length, 15);
    for (final row in rows) {
      final route = provinceRoutes.singleWhere((r) => r.id == row['id']);
      expect(route.destination, row['destination']);
      expect(route.province, row['province']);
      expect(route.fareCents, row['fare_cents']);
    }
  });
  test(
    'QR de provincia valida importes grupales y rechaza destinos pendientes',
    () {
      expect(
        TripQr.tryParse(
          'CONDUCTOR:2:provincia_la_guardia:8:ruta-001:1',
        )?.puntos,
        8,
      );
      expect(
        TripQr.tryParse(
          'CONDUCTOR:2:provincia_el_torno:25.50:ruta-002:3',
        )?.provinceRoute?.destination,
        'El Torno',
      );
      for (final raw in [
        'CONDUCTOR:2:provincia_el_torno:25:ruta-002:3',
        'CONDUCTOR:2:provincia_samaipata:25:ruta-002:1',
        'CONDUCTOR:2:provincia_el_torno:0:ruta-002:0',
      ]) {
        expect(TripQr.tryParse(raw), isNull);
      }
    },
  );
  test(
    'pago provincial descuenta 25.50 una vez y no abre un atajo NFC desde el cliente',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection('usuarios').doc('u-1').set({
        'id': 1,
        'estado': 'activo',
        'tipo': 'civil',
        'puntos': 30,
        'nombre': 'Pasajero',
      });
      await db.collection('conductores').doc('c-2').set({
        'id': 2,
        'estado': 'activo',
      });
      final service = FirebaseService.forTesting(db);
      Future<({bool ok, String message})> pay(String method) =>
          service.pagarViaje(
            userId: 1,
            conductorId: 2,
            puntos: 25.50,
            metodoPago: method,
            tipoUsuario: 'provincia_el_torno',
            paymentReference: 'province-group',
            cantidadPasajeros: 3,
          );
      expect((await pay('nfc')).ok, isFalse);
      expect((await pay('qr')).ok, isTrue);
      expect((await pay('qr')).ok, isFalse);
      expect(
        (await db.collection('usuarios').doc('u-1').get()).data()!['puntos'],
        4.5,
      );
      final payment = (await db.collection('transacciones').get()).docs.single
          .data();
      expect(payment['ruta_id'], 'el_torno');
      expect(payment['cantidad_pasajeros'], 3);
    },
  );
  test(
    'NFC exige prueba dinámica; UID y datos de tarjeta bancaria no bastan',
    () {
      expect(
        CardProof.tryParse('TRANSITA1:04DE5F1EACC040:3D0000:94EED9EE65337086'),
        isNotNull,
      );
      for (final raw in [
        '04DE5F1EACC040',
        'TRANSITA1:04DE5F1EACC040',
        'TRANSITA1:04DE5F1EACC040:XXXXXX:94EED9EE65337086',
        'CONDUCTOR:2:civil:3.5:x:1',
      ]) {
        expect(CardProof.tryParse(raw), isNull);
      }
    },
  );
  testWidgets(
    'Provincias filtra los destinos y conserva centavos para grupos',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProvinceRoutesScreen()));
      expect(find.text('La Guardia'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Añadir un pasaje'));
        await tester.pump();
      }
      expect(find.textContaining('Total Bs 25.50'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Samaipata');
      await tester.pump();
      expect(find.text('La Guardia'), findsNothing);
      expect(find.text('Tarifa pendiente de verificar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'POS de tablet no aprueba pagos cuando el servicio está sin activar',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => DriverAuthService(),
          child: const MaterialApp(home: PosScreen()),
        ),
      );
      await tester.enterText(find.byType(TextField), '8.50');
      await tester.ensureVisible(find.text('COBRAR CON TARJETA'));
      await tester.tap(find.text('COBRAR CON TARJETA'));
      await tester.pump();
      expect(
        find.textContaining('Terminal pendiente de activación.'),
        findsOneWidget,
      );
      expect(find.textContaining('PAGO APROBADO'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
