import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_chat.dart';

/// Conversación en vivo y operaciones verificadas por el operador.
/// La reserva diaria serializa los retiros y evita solicitar dos veces el saldo.
class FinancialChatService {
  FinancialChatService({this._firestore});
  static final instance = FinancialChatService();
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('solicitudes_financieras');

  static String dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  DocumentReference<Map<String, dynamic>> _ledger(int id, String day) =>
      _db.collection('liquidaciones').doc('c-$id-$day');

  Future<void> ensureChat(ChatIdentity owner) async {
    if (owner.id <= 0 || !['pasajero', 'conductor'].contains(owner.canal)) {
      throw const ChatFailure('Perfil no válido. Vuelve a iniciar sesión.');
    }
    final ref = _chats.doc(owner.chatId);
    await _db.runTransaction((txn) async {
      if ((await txn.get(ref)).exists) return;
      txn.set(ref, {
        'canal': owner.canal,
        'id_cliente': owner.id,
        'nombre': owner.nombre,
        'ultimo_mensaje': '',
        'fecha_creacion': FieldValue.serverTimestamp(),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<Map<String, dynamic>>> chatsStream() => _chats
      .orderBy('fecha_actualizacion', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'doc_id': d.id}).toList());

  Stream<List<Map<String, dynamic>>> messagesStream(String chatId) => _chats
      .doc(chatId)
      .collection('mensajes')
      .orderBy('fecha', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'doc_id': d.id}).toList());

  Stream<List<FinancialRequest>> requestsStream(String chatId) =>
      _requests.where('chat_id', isEqualTo: chatId).snapshots().map((s) {
        final docs = s.docs.toList()
          ..sort((a, b) {
            final aTime =
                (a.data()['fecha_creacion'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            final bTime =
                (b.data()['fecha_creacion'] as Timestamp?)
                    ?.millisecondsSinceEpoch ??
                0;
            return bTime.compareTo(aTime);
          });
        return docs.map(FinancialRequest.fromDoc).toList();
      });

  Future<void> sendMessage(
    ChatIdentity owner,
    String text, {
    bool admin = false,
    String adminName = '',
    int? adminId,
  }) async {
    text = text.trim();
    if (text.isEmpty || text.length > 1000) {
      throw const ChatFailure('Escribe un mensaje de hasta 1000 caracteres.');
    }
    if (admin) await _verifyAdmin(adminId);
    final batch = _db.batch();
    batch.set(_chats.doc(owner.chatId).collection('mensajes').doc(), {
      'texto': text,
      'autor': admin ? 'admin' : 'cliente',
      'nombre': admin ? adminName : owner.nombre,
      'fecha': FieldValue.serverTimestamp(),
    });
    batch.update(_chats.doc(owner.chatId), {
      'ultimo_mensaje': text,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _verifyAdmin(int? id) async {
    final doc = await _db.collection('usuarios').doc('admin').get();
    final data = doc.data();
    if (id == null ||
        data?['id'] != id ||
        data?['rol'] != 'ADMIN' ||
        data?['estado'] != 'activo') {
      throw const ChatFailure('La operación requiere un administrador activo.');
    }
  }

  int _income(Iterable<Map<String, dynamic>> documents, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    var total = 0;
    for (final m in documents) {
      final date = m['fecha'];
      if (m['tipo'] != 'cobro_viaje' ||
          m['estado'] != 'exitoso' ||
          date is! Timestamp) {
        continue;
      }
      final local = date.toDate().toLocal();
      if (!local.isBefore(start) && local.isBefore(end)) {
        total += (m['puntos'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  Future<WithdrawalBalance> withdrawalBalance(int id, {DateTime? day}) async {
    final date = day ?? DateTime.now();
    final income = await _db
        .collection('transacciones')
        .where('id_conductor', isEqualTo: id)
        .get(const GetOptions(source: Source.server));
    final ledger = (await _ledger(
      id,
      dayKey(date),
    ).get(const GetOptions(source: Source.server))).data();
    return WithdrawalBalance(
      ingresos: _income(income.docs.map((d) => d.data()), date),
      reservado: (ledger?['reservado'] as num?)?.toInt() ?? 0,
      retirado: (ledger?['retirado'] as num?)?.toInt() ?? 0,
    );
  }

  Stream<WithdrawalBalance> withdrawalBalanceStream(int id, {DateTime? day}) {
    final selectedDay = day ?? DateTime.now();
    List<Map<String, dynamic>>? income;
    Map<String, dynamic>? ledger;
    var ledgerReady = false;
    late StreamController<WithdrawalBalance> controller;
    final subs = <StreamSubscription<dynamic>>[];
    void emit() {
      if (income == null || !ledgerReady || controller.isClosed) return;
      controller.add(
        WithdrawalBalance(
          ingresos: _income(income!, selectedDay),
          reservado: (ledger?['reservado'] as num?)?.toInt() ?? 0,
          retirado: (ledger?['retirado'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    controller = StreamController<WithdrawalBalance>(
      onListen: () {
        subs.add(
          _db
              .collection('transacciones')
              .where('id_conductor', isEqualTo: id)
              .snapshots()
              .listen((s) {
                income = s.docs.map((d) => d.data()).toList();
                emit();
              }, onError: controller.addError),
        );
        subs.add(
          _ledger(id, dayKey(selectedDay)).snapshots().listen((s) {
            ledger = s.data();
            ledgerReady = true;
            emit();
          }, onError: controller.addError),
        );
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<String> request(
    ChatIdentity owner,
    int amount,
    String detail, {
    DateTime? day,
  }) async {
    if (amount <= 0 || amount > 1000000 || detail.trim().length > 1000) {
      throw const ChatFailure(
        'Introduce un monto válido en bolivianos enteros.',
      );
    }
    await ensureChat(owner);
    final date = day ?? DateTime.now();
    // Los cobros son inmutables. Un ingreso nuevo posterior a esta lectura
    // solo aumenta el disponible; la reserva se valida dentro de la transacción.
    final income = owner.isDriver
        ? (await withdrawalBalance(owner.id, day: date)).ingresos
        : 0;
    final ref = _requests.doc();
    final ledgerRef = _ledger(owner.id, dayKey(date));
    final ownerRef = _db
        .collection(owner.isDriver ? 'conductores' : 'usuarios')
        .doc('${owner.isDriver ? 'c' : 'u'}-${owner.id}');
    await _db.runTransaction((txn) async {
      final account = await txn.get(ownerRef);
      if (!account.exists || account.data()?['estado'] != 'activo') {
        throw const ChatFailure(
          'Tu cuenta no está activa. Contacta a soporte.',
        );
      }
      Map<String, dynamic>? ledger;
      if (owner.isDriver) {
        ledger = (await txn.get(ledgerRef)).data();
        final reserved = (ledger?['reservado'] as num?)?.toInt() ?? 0;
        final paid = (ledger?['retirado'] as num?)?.toInt() ?? 0;
        if (amount > income - reserved - paid) {
          throw const ChatFailure(
            'El monto supera tu recaudación diaria disponible.',
          );
        }
        txn.set(ledgerRef, {
          'id_conductor': owner.id,
          'dia': dayKey(date),
          'reservado': reserved + amount,
          'retirado': paid,
        });
      }
      txn.set(ref, {
        'chat_id': owner.chatId,
        'id_cliente': owner.id,
        'canal': owner.canal,
        'monto': amount,
        'detalle': detail.trim(),
        'dia': dayKey(date),
        'estado': 'pendiente',
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      _writeSystemMessage(
        txn,
        owner.chatId,
        'solicitud-${ref.id}',
        'Solicitud de ${owner.operation}: Bs $amount.00. Pendiente de confirmación del operador.'
            '${detail.trim().isEmpty ? '' : '\n${detail.trim()}'}',
      );
    });
    return ref.id;
  }

  Future<void> resolve(
    String requestId, {
    required bool approve,
    required int adminId,
    required String adminName,
    String note = '',
  }) async {
    if (note.trim().length > 1000) {
      throw const ChatFailure('La observación es demasiado larga.');
    }
    final ref = _requests.doc(requestId);
    await _db.runTransaction((txn) async {
      final admin = (await txn.get(
        _db.collection('usuarios').doc('admin'),
      )).data();
      if (admin?['id'] != adminId ||
          admin?['rol'] != 'ADMIN' ||
          admin?['estado'] != 'activo') {
        throw const ChatFailure(
          'La operación requiere un administrador activo.',
        );
      }
      final doc = await txn.get(ref);
      if (!doc.exists) throw const ChatFailure('Solicitud no encontrada.');
      final req = FinancialRequest.fromDoc(doc);
      if (!req.pending) {
        throw const ChatFailure('Esta solicitud ya fue atendida.');
      }
      final ledgerRef = _ledger(req.ownerId, req.dia);
      final userRef = _db.collection('usuarios').doc('u-${req.ownerId}');
      Map<String, dynamic>? ledger;
      Map<String, dynamic>? user;
      if (req.isWithdrawal) {
        ledger = (await txn.get(ledgerRef)).data();
        if (((ledger?['reservado'] as num?)?.toInt() ?? 0) < req.monto) {
          throw const ChatFailure(
            'No hay una reserva válida para este retiro.',
          );
        }
      } else if (approve) {
        user = (await txn.get(userRef)).data();
        if (user == null || user['estado'] != 'activo') {
          throw const ChatFailure('El pasajero no está activo.');
        }
      }
      if (req.isWithdrawal) {
        txn.update(ledgerRef, {
          'reservado':
              ((ledger?['reservado'] as num?)?.toInt() ?? 0) - req.monto,
          'retirado':
              ((ledger?['retirado'] as num?)?.toInt() ?? 0) +
              (approve ? req.monto : 0),
        });
      } else if (approve) {
        txn.update(userRef, {
          'puntos': ((user?['puntos'] as num?)?.toInt() ?? 0) + req.monto,
        });
      }
      if (approve) {
        txn.set(_db.collection('transacciones').doc('chat-$requestId'), {
          'id':
              DateTime.now().microsecondsSinceEpoch *
              (req.isWithdrawal ? 1 : -1),
          'id_usuario': req.isWithdrawal ? null : req.ownerId,
          'id_conductor': req.isWithdrawal ? req.ownerId : 0,
          'tipo': req.isWithdrawal ? 'retiro_conductor' : 'recarga',
          'estado': req.isWithdrawal ? 'exitoso' : 'exitosa',
          'puntos': req.monto,
          'metodo_pago': 'chat',
          'solicitud_id': requestId,
          'fecha': FieldValue.serverTimestamp(),
          'fecha_cliente': DateTime.now().toUtc(),
        });
      }
      txn.update(ref, {
        'estado': approve ? 'aprobada' : 'rechazada',
        'fecha_resolucion': FieldValue.serverTimestamp(),
        'operador': adminName,
        'observacion': note.trim(),
      });
      _writeSystemMessage(
        txn,
        req.chatId,
        'resolucion-$requestId',
        '${req.isWithdrawal ? 'Retiro' : 'Recarga'} de Bs ${req.monto}.00 '
            '${approve ? 'confirmado' : 'rechazado'} por $adminName.'
            '${note.trim().isEmpty ? '' : '\n${note.trim()}'}',
      );
    });
  }

  void _writeSystemMessage(
    Transaction txn,
    String chatId,
    String messageId,
    String text,
  ) {
    txn.set(_chats.doc(chatId).collection('mensajes').doc(messageId), {
      'texto': text,
      'autor': 'sistema',
      'nombre': 'Atención',
      'fecha': FieldValue.serverTimestamp(),
    });
    txn.update(_chats.doc(chatId), {
      'ultimo_mensaje': text,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }
}
