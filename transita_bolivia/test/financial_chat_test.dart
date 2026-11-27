import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transita_bolivia/models/financial_chat.dart';
import 'package:transita_bolivia/services/financial_chat_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FinancialChatService service;
  const passenger = ChatIdentity(canal: 'pasajero', id: 1, nombre: 'Ana');
  const driver = ChatIdentity(canal: 'conductor', id: 2, nombre: 'Juan');
  final day = DateTime(2026, 10, 15, 12);
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = FinancialChatService(firestore: db);
    await db.collection('usuarios').doc('u-1').set({
      'id': 1,
      'estado': 'activo',
      'puntos': 10,
    });
    await db.collection('usuarios').doc('admin').set({
      'id': 0,
      'rol': 'ADMIN',
      'estado': 'activo',
    });
    await db.collection('conductores').doc('c-2').set({
      'id': 2,
      'estado': 'activo',
    });
    await db.collection('transacciones').doc('viaje').set({
      'id_conductor': 2,
      'tipo': 'cobro_viaje',
      'estado': 'exitoso',
      'puntos': 20,
      'fecha': Timestamp.fromDate(day),
    });
  });
  Future<num> points() async =>
      (await db.collection('usuarios').doc('u-1').get()).data()!['puntos']
          as num;
  Future<void> resolve(String id, {bool approve = true, int admin = 0}) =>
      service.resolve(
        id,
        approve: approve,
        adminId: admin,
        adminName: 'Operador',
      );

  test(
    'la solicitud de recarga no acredita hasta confirmación; solo se acredita una vez',
    () async {
      final id = await service.request(passenger, 5, 'Referencia de pago');
      expect(await points(), 10);
      expect(
        (await db.collection('solicitudes_financieras').doc(id).get())
            .data()!['estado'],
        'pendiente',
      );
      await resolve(id);
      expect(await points(), 15);
      expect(
        (await db.collection('transacciones').doc('chat-$id').get())
            .data()!['tipo'],
        'recarga',
      );
      await expectLater(resolve(id), throwsA(isA<ChatFailure>()));
      expect(await points(), 15);
    },
  );
  test('rechazar una recarga no cambia el saldo', () async {
    final id = await service.request(passenger, 5, 'Consulta');
    await resolve(id, approve: false);
    expect(await points(), 10);
    expect(
      (await db.collection('transacciones').doc('chat-$id').get()).exists,
      isFalse,
    );
  });
  test(
    'el retiro reserva el disponible y evita dos solicitudes sobre el mismo saldo',
    () async {
      final id = await service.request(driver, 8, 'Retiro de hoy', day: day);
      var balance = await service.withdrawalBalance(2, day: day);
      expect(balance.disponible, 12);
      expect(balance.reservado, 8);
      await expectLater(
        service.request(driver, 13, '', day: day),
        throwsA(isA<ChatFailure>()),
      );
      expect(
        (await db.collection('solicitudes_financieras').get()).docs,
        hasLength(1),
      );
      await resolve(id);
      balance = await service.withdrawalBalance(2, day: day);
      expect(balance.retirado, 8);
      expect(balance.reservado, 0);
      expect(balance.disponible, 12);
      expect(
        (await db.collection('transacciones').doc('chat-$id').get())
            .data()!['tipo'],
        'retiro_conductor',
      );
      await expectLater(resolve(id), throwsA(isA<ChatFailure>()));
    },
  );
  test('rechazar un retiro libera el dinero reservado', () async {
    final id = await service.request(driver, 8, '', day: day);
    await resolve(id, approve: false);
    final balance = await service.withdrawalBalance(2, day: day);
    expect(balance.disponible, 20);
    expect(balance.retirado, 0);
    expect(balance.reservado, 0);
  });
  test(
    'el retiro usa solo los cobros exitosos del conductor y del día elegido',
    () async {
      for (final extra in [
        {
          'id_conductor': 99,
          'tipo': 'cobro_viaje',
          'estado': 'exitoso',
          'fecha': Timestamp.fromDate(day),
        },
        {
          'id_conductor': 2,
          'tipo': 'cobro_viaje',
          'estado': 'exitoso',
          'fecha': Timestamp.fromDate(day.subtract(const Duration(days: 1))),
        },
        {
          'id_conductor': 2,
          'tipo': 'cobro_viaje',
          'estado': 'anulado',
          'fecha': Timestamp.fromDate(day),
        },
        {
          'id_conductor': 2,
          'tipo': 'recarga',
          'estado': 'exitosa',
          'fecha': Timestamp.fromDate(day),
        },
      ]) {
        await db.collection('transacciones').add({...extra, 'puntos': 100});
      }
      expect((await service.withdrawalBalance(2, day: day)).ingresos, 20);
      await expectLater(
        service.request(driver, 21, '', day: day),
        throwsA(isA<ChatFailure>()),
      );
    },
  );
  test('se rechazan montos inválidos y operadores sin acceso', () async {
    await expectLater(
      service.request(passenger, 0, ''),
      throwsA(isA<ChatFailure>()),
    );
    await expectLater(
      service.request(driver, -2, '', day: day),
      throwsA(isA<ChatFailure>()),
    );
    final id = await service.request(passenger, 5, '');
    await expectLater(resolve(id, admin: 99), throwsA(isA<ChatFailure>()));
    expect(await points(), 10);
  });
  test(
    'cliente y operador intercambian mensajes; se actualiza la conversación',
    () async {
      await service.ensureChat(passenger);
      await service.sendMessage(passenger, 'Quiero recargar');
      await service.sendMessage(
        passenger,
        'Indica tu referencia',
        admin: true,
        adminId: 0,
        adminName: 'Operador',
      );
      final messages = await service.messagesStream(passenger.chatId).first;
      expect(messages, hasLength(2));
      expect(
        messages.map((m) => m['autor']),
        containsAll(['cliente', 'admin']),
      );
      expect(
        (await db.collection('chats').doc(passenger.chatId).get())
            .data()!['ultimo_mensaje'],
        'Indica tu referencia',
      );
      await expectLater(
        service.sendMessage(
          passenger,
          'No autorizado',
          admin: true,
          adminId: 99,
        ),
        throwsA(isA<ChatFailure>()),
      );
    },
  );
  test('recargar cincuenta centavos conserva la fracción del saldo', () async {
    final id = await service.request(passenger, 0.50, 'Recarga con centavos');
    await resolve(id);
    final data = (await db.collection('usuarios').doc('u-1').get()).data()!;
    expect(data['puntos'], 10.50);
  });

  test('recaudación y retiro diario conservan cincuenta centavos', () async {
    await db.collection('transacciones').doc('civil').set({
      'id_conductor': 2,
      'tipo': 'cobro_viaje',
      'estado': 'exitoso',
      'puntos': 3.50,
      'fecha': Timestamp.fromDate(day),
    });
    final id = await service.request(driver, 3.50, 'Retiro', day: day);
    var balance = await service.withdrawalBalance(2, day: day);
    expect(balance.ingresos, 23.50);
    expect(balance.reservado, 3.50);
    expect(balance.disponible, 20);
    await resolve(id);
    balance = await service.withdrawalBalance(2, day: day);
    expect(balance.retirado, 3.50);
    expect(balance.reservado, 0);
    expect(balance.disponible, 20);
    await expectLater(
      service.request(passenger, 0.001, ''),
      throwsA(isA<ChatFailure>()),
    );
  });
}
