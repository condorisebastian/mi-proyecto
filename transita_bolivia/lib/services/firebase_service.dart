import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app;
import '../models/transaction.dart' as app_tx;
import '../models/conductor.dart';

/// Capa de datos sobre Firebase (Cloud Firestore).
///
/// Replica el contrato del backend PHP usando Firebase. El identificador de
/// acceso es un PIN único de 4 dígitos por usuario:
///  - Pasajero: se busca en `usuarios` por `pin` (+ `tipo`).
///  - Conductor: se busca en `conductores` por `pin`.
/// Las colecciones `usuarios`, `conductores` y `transacciones` usan el modelo
/// de "puntos" que consume la app.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  static const String _usersCollection = 'usuarios';
  static const String _conductoresCollection = 'conductores';
  static const String _transaccionesCollection = 'transacciones';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // =====================================================================
  // AUTH (por PIN)
  // =====================================================================

  /// Verifica si un PIN ya está en uso en `usuarios` o `conductores`.
  Future<bool> _pinEnUso(String pin) async {
    final u = await _db
        .collection(_usersCollection)
        .where('pin', isEqualTo: pin)
        .limit(1)
        .get();
    if (u.docs.isNotEmpty) return true;
    final c = await _db
        .collection(_conductoresCollection)
        .where('pin', isEqualTo: pin)
        .limit(1)
        .get();
    return c.docs.isNotEmpty;
  }

  /// Verifica si un CI ya está registrado en la colección indicada.
  Future<bool> _ciEnUso(String collection, String ci) async {
    final snap = await _db
        .collection(collection)
        .where('ci', isEqualTo: ci)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Autentica a un pasajero por su PIN único + tipo (el CI es opcional;
  /// si se ingresa, debe coincidir con el de la cuenta).
  Future<app.User?> loginPasajero(String pin, String tipo,
      {String ci = ''}) async {
    final snap = await _db
        .collection(_usersCollection)
        .where('pin', isEqualTo: pin)
        .where('rol', isEqualTo: 'PASAJERO')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final user = _userFromMap(snap.docs.first.data());
    if (user.tipo != tipo) return null;
    if (ci.isNotEmpty && user.ci.isNotEmpty && user.ci != ci) return null;
    return user;
  }

  /// Autentica a un conductor por su PIN único (CI opcional).
  Future<Conductor?> loginConductor(String pin, {String ci = ''}) async {
    final snap = await _db
        .collection(_conductoresCollection)
        .where('pin', isEqualTo: pin)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final conductor = _conductorFromMap(snap.docs.first.data());
    if (ci.isNotEmpty && conductor.ci.isNotEmpty && conductor.ci != ci) {
      return null;
    }
    return conductor;
  }

  /// Registra un pasajero en Firestore con PIN único.
  Future<app.User?> registerPasajero({
    required String nombre,
    required String apellido,
    required String ci,
    required String pin,
    required String tipo,
  }) async {
    if (pin.length != 4) return null;
    if (await _pinEnUso(pin)) return null;
    if (ci.isNotEmpty && await _ciEnUso(_usersCollection, ci)) return null;
    final nextId = await _nextId(_usersCollection);
    final doc = {
      'id': nextId,
      'nombre': nombre,
      'apellido': apellido,
      'ci': ci,
      'email': '',
      'pin': pin,
      'tipo': tipo,
      'puntos': 0,
      'estado': 'activo',
      'rol': 'PASAJERO',
    };
    try {
      await _db.collection(_usersCollection).doc('u-$nextId').set(doc);
    } catch (_) {
      return null;
    }
    return _userFromMap(doc);
  }

  /// Registra un conductor en Firestore con PIN único.
  Future<Conductor?> registerConductor({
    required String nombre,
    required String apellido,
    required String ci,
    required String pin,
    String? licencia,
    String? telefono,
  }) async {
    if (pin.length != 4) return null;
    if (await _pinEnUso(pin)) return null;
    if (ci.isNotEmpty && await _ciEnUso(_conductoresCollection, ci)) {
      return null;
    }
    final nextId = await _nextId(_conductoresCollection);
    final lic = licencia ?? 'LIC-$nextId';
    final doc = {
      'id': nextId,
      'nombre': nombre,
      'apellido': apellido,
      'ci': ci,
      'pin': pin,
      'licencia': lic,
      'telefono': telefono,
      'estado': 'activo',
      'usuario_id': null,
    };
    try {
      await _db
          .collection(_conductoresCollection)
          .doc('c-$nextId')
          .set(doc);
    } catch (_) {
      return null;
    }
    return _conductorFromMap(doc);
  }

  /// Cierra sesión (Firebase no guarda sesión; la sesión la maneja la app).
  Future<void> logout() async {
    // No-op: no hay sesión de Firebase Auth que cerrar.
  }

  // =====================================================================
  // DATOS DE USUARIO / PASAJERO
  // =====================================================================

  /// Devuelve el User pasajero por su id numérico.
  Future<app.User?> fetchUserById(int userId) async {
    final doc = await _db.collection(_usersCollection).doc('u-$userId').get();
    if (!doc.exists) return null;
    return _userFromMap(doc.data()!);
  }

  /// Incrementa (o resta si `delta` es negativo) los puntos del usuario.
  /// Usa una transacción para evitar pérdidas de actualización (doble gasto).
  Future<void> addPuntos(int userId, int delta) async {
    final ref = _db.collection(_usersCollection).doc('u-$userId');
    await _db.runTransaction((txn) async {
      final doc = await txn.get(ref);
      if (!doc.exists) return;
      final current = (doc.data()?['puntos'] as num?)?.toInt() ?? 0;
      final nuevo = current + delta;
      if (nuevo < 0) return;
      txn.update(ref, {'puntos': nuevo});
    });
  }

  // =====================================================================
  // TRANSACCIONES
  // =====================================================================

  /// Devuelve el historial combinado (recargas + cobros) de un usuario.
  Future<List<app_tx.Transaction>> getTransactionHistory(int userId) async {
    final snap = await _db
        .collection(_transaccionesCollection)
        .where('id_usuario', isEqualTo: userId)
        .orderBy('fecha', descending: true)
        .get();
    return snap.docs.map((d) => _transactionFromMap(d.data())).toList();
  }

  /// Registra una recarga de puntos y actualiza el saldo del usuario.
  Future<void> recargar({
    required int userId,
    required int puntos,
    required String metodoPago,
  }) async {
    final userDoc = await _db
        .collection(_usersCollection)
        .doc('u-$userId')
        .get();
    if (!userDoc.exists) return;

    final nextId = await _nextId(_transaccionesCollection);
    final rec = {
      'id': -nextId,
      'id_usuario': userId,
      'id_conductor': 1,
      'puntos': puntos,
      'tipo': 'recarga',
      'metodo_pago': metodoPago,
      'estado': 'exitosa',
      'fecha': DateTime.now().toUtc(),
    };
    await _db.collection(_transaccionesCollection).doc('r-$nextId').set(rec);
    await addPuntos(userId, puntos);
  }

  /// Registra el pago de un viaje y descuenta los puntos del pasajero.
  /// Todo ocurre en una sola transacción atómica (saldo + cobro).
  Future<({bool ok, String message})> pagarViaje({
    required int userId,
    required int conductorId,
    required int puntos,
    required String metodoPago,
    String? tipoUsuario,
  }) async {
    final nextId = await _nextId(_transaccionesCollection);
    final userRef = _db.collection(_usersCollection).doc('u-$userId');
    final cobroRef = _db
        .collection(_transaccionesCollection)
        .doc('c-$nextId');

    try {
      return await _db.runTransaction((txn) async {
        final userSnap = await txn.get(userRef);
        if (!userSnap.exists) {
          return (ok: false, message: 'Usuario no encontrado');
        }
        final data = userSnap.data()!;
        final saldo = (data['puntos'] as num?)?.toInt() ?? 0;
        if (saldo < puntos) {
          return (ok: false, message: 'Saldo insuficiente');
        }

        txn.update(userRef, {'puntos': saldo - puntos});
        txn.set(cobroRef, {
          'id': nextId,
          'id_usuario': userId,
          'id_conductor': conductorId,
          'puntos': puntos,
          'tipo': 'cobro_viaje',
          'metodo_pago': metodoPago,
          'estado': 'exitoso',
          'fecha': DateTime.now().toUtc(),
          'tipo_usuario': tipoUsuario,
          'nombre_pasajero': data['nombre'],
          'apellido_pasajero': data['apellido'],
        });
        return (ok: true, message: 'Viaje pagado');
      });
    } catch (_) {
      return (ok: false, message: 'Error al procesar el pago');
    }
  }

  // =====================================================================
  // CONDUCTOR
  // =====================================================================

  Conductor _conductorFromMap(Map<String, dynamic> m) {
    return Conductor(
      id: (m['id'] as num).toInt(),
      nombre: m['nombre'] as String,
      apellido: m['apellido'] as String,
      ci: (m['ci'] as String?) ?? '',
      licencia: (m['licencia'] as String?) ?? '',
      telefono: m['telefono'] as String?,
      estado: m['estado'] as String,
    );
  }

  /// Registra un viaje cobrado por un conductor y descuenta puntos si el
  /// pasajero está vinculado. Un solo cobro: si hay `userId`, el registro lo
  /// crea `pagarViaje` dentro de su transacción atómica.
  Future<({bool ok, String message})> registrarCobro({
    required int conductorId,
    required String tipoUsuario,
    required int puntos,
    required String metodoPago,
    int? userId,
  }) async {
    if (userId != null) {
      return pagarViaje(
          userId: userId,
          conductorId: conductorId,
          puntos: puntos,
          metodoPago: metodoPago,
          tipoUsuario: tipoUsuario);
    }
    final nextId = await _nextId(_transaccionesCollection);
    final cobro = {
      'id': nextId,
      'id_usuario': userId,
      'id_conductor': conductorId,
      'puntos': puntos,
      'tipo': 'cobro_viaje',
      'metodo_pago': metodoPago,
      'estado': 'exitoso',
      'fecha': DateTime.now().toUtc(),
      'tipo_usuario': tipoUsuario,
      'nombre_pasajero': '',
      'apellido_pasajero': '',
    };
    try {
      await _db.collection(_transaccionesCollection).doc('c-$nextId').set(cobro);
    } catch (_) {
      return (ok: false, message: 'Error al registrar el cobro');
    }
    return (ok: true, message: 'Cobro registrado');
  }

  /// Resumen diario del conductor (lista en forma de mapa del contrato PHP).
  Future<Map<String, dynamic>> getDailySummary(int conductorId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _db
        .collection(_transaccionesCollection)
        .where('id_conductor', isEqualTo: conductorId)
        .where('tipo', isEqualTo: 'cobro_viaje')
        .where('estado', isEqualTo: 'exitoso')
        .where('fecha', isGreaterThanOrEqualTo: start)
        .where('fecha', isLessThan: end)
        .get();

    int totalPasajeros = 0;
    int totalPuntos = 0;
    int estudiantes = 0;
    int civiles = 0;
    int mayores = 0;
    int discapacitados = 0;

    for (final d in snap.docs) {
      final m = d.data();
      totalPasajeros++;
      totalPuntos += (m['puntos'] as num?)?.toInt() ?? 0;
      final tipo = m['tipo_usuario'] as String? ?? 'civil';
      switch (tipo) {
        case 'estudiante':
          estudiantes++;
          break;
        case 'civil':
          civiles++;
          break;
        case 'adulto_mayor':
          mayores++;
          break;
        case 'discapacitado':
          discapacitados++;
          break;
      }
    }

    return {
      'total_pasajeros': totalPasajeros,
      'total_puntos': totalPuntos,
      'estudiantes': estudiantes,
      'civiles': civiles,
      'mayores': mayores,
      'discapacitados': discapacitados,
    };
  }

  /// Historial diario del conductor como mapas del contrato PHP.
  Future<List<Map<String, dynamic>>> getDailyHistory(int conductorId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _db
        .collection(_transaccionesCollection)
        .where('id_conductor', isEqualTo: conductorId)
        .where('tipo', isEqualTo: 'cobro_viaje')
        .where('estado', isEqualTo: 'exitoso')
        .where('fecha', isGreaterThanOrEqualTo: start)
        .where('fecha', isLessThan: end)
        .orderBy('fecha', descending: true)
        .get();

    final out = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final m = d.data();
      final userId = m['id_usuario'] as int?;
      out.add({
        'id': m['id'],
        'id_usuario': userId,
        'id_conductor': m['id_conductor'],
        'puntos': m['puntos'],
        'tipo': m['tipo'],
        'metodo_pago': m['metodo_pago'],
        'estado': m['estado'],
        'fecha': _formatFecha(m['fecha']),
        'nombre': (m['nombre_pasajero'] as String?)?.isNotEmpty == true
            ? m['nombre_pasajero'] as String
            : await _nombreByUserId(userId),
        'apellido': '',
        'tipo_usuario': m['tipo_usuario'] ?? '',
      });
    }
    return out;
  }

  Future<String> _nombreByUserId(int? userId) async {
    if (userId == null) return '';
    final doc = await _db.collection(_usersCollection).doc('u-$userId').get();
    if (!doc.exists) return '';
    return (doc.data()?['nombre'] as String?) ?? '';
  }

  // =====================================================================
  // TIEMPO REAL (snapshots)
  // =====================================================================

  /// Saldo/datos del pasajero en vivo (se actualiza al recargar/pagar).
  Stream<app.User?> userStream(int userId) {
    return _db
        .collection(_usersCollection)
        .doc('u-$userId')
        .snapshots()
        .map((ds) => ds.exists ? _userFromMap(ds.data()!) : null);
  }

  /// Historial del pasajero en vivo (recargas + cobros).
  Stream<List<app_tx.Transaction>> transactionHistoryStream(int userId) {
    return _db
        .collection(_transaccionesCollection)
        .where('id_usuario', isEqualTo: userId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((qs) =>
            qs.docs.map((d) => _transactionFromMap(d.data())).toList());
  }

  /// Resumen diario del conductor en vivo.
  Stream<Map<String, dynamic>> dailySummaryStream(int conductorId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final query = _db
        .collection(_transaccionesCollection)
        .where('id_conductor', isEqualTo: conductorId)
        .where('tipo', isEqualTo: 'cobro_viaje')
        .where('estado', isEqualTo: 'exitoso')
        .where('fecha', isGreaterThanOrEqualTo: start)
        .where('fecha', isLessThan: end);

    return query.snapshots().map((qs) {
      int totalPasajeros = 0;
      int totalPuntos = 0;
      int estudiantes = 0;
      int civiles = 0;
      int mayores = 0;
      int discapacitados = 0;

      for (final d in qs.docs) {
        final m = d.data();
        totalPasajeros++;
        totalPuntos += (m['puntos'] as num?)?.toInt() ?? 0;
        final tipo = m['tipo_usuario'] as String? ?? 'civil';
        switch (tipo) {
          case 'estudiante':
            estudiantes++;
            break;
          case 'civil':
            civiles++;
            break;
          case 'adulto_mayor':
            mayores++;
            break;
          case 'discapacitado':
            discapacitados++;
            break;
        }
      }

      return {
        'total_pasajeros': totalPasajeros,
        'total_puntos': totalPuntos,
        'estudiantes': estudiantes,
        'civiles': civiles,
        'mayores': mayores,
        'discapacitados': discapacitados,
      };
    });
  }

  /// Cobros del día en vivo (para el historial del conductor).
  Stream<List<Map<String, dynamic>>> dailyHistoryStream(int conductorId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return _db
        .collection(_transaccionesCollection)
        .where('id_conductor', isEqualTo: conductorId)
        .where('tipo', isEqualTo: 'cobro_viaje')
        .where('estado', isEqualTo: 'exitoso')
        .where('fecha', isGreaterThanOrEqualTo: start)
        .where('fecha', isLessThan: end)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) {
              final m = d.data();
              return {
                'id': m['id'],
                'id_usuario': m['id_usuario'],
                'id_conductor': m['id_conductor'],
                'puntos': m['puntos'],
                'tipo': m['tipo'],
                'metodo_pago': m['metodo_pago'],
                'estado': m['estado'],
                'fecha': _formatFecha(m['fecha']),
                'nombre': (m['nombre_pasajero'] as String?) ?? '',
                'apellido': (m['apellido_pasajero'] as String?) ?? '',
                'tipo_usuario': m['tipo_usuario'] ?? '',
              };
            }).toList());
  }

  // =====================================================================
  // ADMIN (registros en vivo)
  // =====================================================================

  /// Crea el usuario ADMIN (PIN 0000) si aún no existe en Firestore.
  Future<void> ensureAdminUser() async {
    final ref = _db.collection(_usersCollection).doc('admin');
    try {
      final doc = await ref.get();
      if (doc.exists) return;
      await ref.set({
        'id': 0,
        'nombre': 'Administrador',
        'apellido': 'Sistema',
        'ci': '',
        'email': 'admin@transita.bo',
        'pin': '0000',
        'tipo': 'civil',
        'puntos': 0,
        'estado': 'activo',
        'rol': 'ADMIN',
      });
    } catch (_) {
      // Sin acceso no impide el arranque de la app.
    }
  }

  /// Autentica al administrador por su PIN.
  Future<app.User?> loginAdmin(String pin) async {
    final snap = await _db
        .collection(_usersCollection)
        .where('rol', isEqualTo: 'ADMIN')
        .where('pin', isEqualTo: pin)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _userFromMap(snap.docs.first.data());
  }

  /// Todos los usuarios en vivo (para el panel admin).
  Stream<List<Map<String, dynamic>>> adminUsuariosStream() {
    return _db.collection(_usersCollection).snapshots().map((qs) {
      final list = qs.docs.map((d) => d.data()).toList();
      list.sort((a, b) => ((b['id'] as num?)?.toInt() ?? 0)
          .compareTo((a['id'] as num?)?.toInt() ?? 0));
      return list;
    });
  }

  /// Todos los conductores en vivo (para el panel admin).
  Stream<List<Map<String, dynamic>>> adminConductoresStream() {
    return _db.collection(_conductoresCollection).snapshots().map((qs) {
      final list = qs.docs.map((d) => d.data()).toList();
      list.sort((a, b) => ((b['id'] as num?)?.toInt() ?? 0)
          .compareTo((a['id'] as num?)?.toInt() ?? 0));
      return list;
    });
  }

  /// Últimas transacciones en vivo (para el panel admin).
  Stream<List<Map<String, dynamic>>> adminTransaccionesStream() {
    return _db
        .collection(_transaccionesCollection)
        .orderBy('fecha', descending: true)
        .limit(100)
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
  }

  // =====================================================================
  // HELPERS
  // =====================================================================

  Future<int> _nextId(String collection) async {
    final snap = await _db.collection(collection).get();
    int max = 0;
    for (final d in snap.docs) {
      final v = (d.data()['id'] as num?)?.toInt() ?? 0;
      if (v.abs() > max) max = v.abs();
    }
    return max + 1;
  }

  app.User _userFromMap(Map<String, dynamic> m) {
    return app.User(
      id: (m['id'] as num).toInt(),
      nombre: m['nombre'] as String,
      apellido: m['apellido'] as String,
      ci: (m['ci'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      tipo: m['tipo'] as String,
      puntos: (m['puntos'] as num?)?.toInt() ?? 0,
      estado: m['estado'] as String,
    );
  }

  app_tx.Transaction _transactionFromMap(Map<String, dynamic> m) {
    return app_tx.Transaction(
      id: (m['id'] as num).toInt(),
      idUsuario: (m['id_usuario'] as num?)?.toInt(),
      idConductor: (m['id_conductor'] as num).toInt(),
      puntos: (m['puntos'] as num).toInt(),
      tipo: m['tipo'] as String,
      metodoPago: m['metodo_pago'] as String,
      estado: m['estado'] as String,
      fecha: (m['fecha'] as Timestamp).toDate(),
    );
  }

  String _formatFecha(dynamic fecha) {
    if (fecha is Timestamp) {
      final d = fecha.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    }
    return '';
  }
}
