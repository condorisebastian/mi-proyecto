import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app;
import '../models/transaction.dart' as app_tx;
import '../models/conductor.dart';

/// Capa de datos sobre Firebase (Auth + Cloud Firestore).
///
/// Replica el contrato del backend PHP usando Firebase:
///  - Auth: login/registro por email+contraseña (los usuarios de prueba usan
///    correos como sebastian@test.com con password 123456). La app pide CI o
///    licencia, así que primero se resuelve el correo desde Firestore y luego
///    se autentica en Firebase Auth.
///  - Firestore: colecciones `usuarios`, `conductores` y `transacciones` con
///    el modelo de "puntos" que consume la app.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  static const String _usersCollection = 'usuarios';
  static const String _conductoresCollection = 'conductores';
  static const String _transaccionesCollection = 'transacciones';

  fb_auth.FirebaseAuth get _auth => fb_auth.FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // =====================================================================
  // AUTH
  // =====================================================================

  /// Busca el usuario pasajero por CI en Firestore y devuelve su `email`.
  Future<String?> _emailByCi(String ci) async {
    final snap = await _db
        .collection(_usersCollection)
        .where('ci', isEqualTo: ci)
        .where('rol', isEqualTo: 'PASAJERO')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['email'] as String?;
  }

  /// Busca el conductor por licencia en Firestore. Devuelve el mapa del
  /// conductor y el email del usuario vinculado (proveniente de `usuarios`).
  Future<({Map<String, dynamic> conductor, String email})?> _conductorByLicencia(
      String licencia) async {
    final condSnap = await _db
        .collection(_conductoresCollection)
        .where('licencia', isEqualTo: licencia)
        .limit(1)
        .get();
    if (condSnap.docs.isEmpty) return null;
    final cond = condSnap.docs.first.data();
    final usuarioId = cond['usuario_id'] as int?;
    String? email;
    if (usuarioId != null) {
      final userDoc = await _db
          .collection(_usersCollection)
          .doc('u-$usuarioId')
          .get();
      email = userDoc.data()?['email'] as String?;
    }
    if (email == null) return null;
    return (conductor: cond, email: email);
  }

  /// Autentica a un pasajero por CI + contraseña.
  Future<app.User?> loginPasajero(String ci, String password, String tipo) async {
    final email = await _emailByCi(ci);
    if (email == null) return null;
    try {
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } catch (_) {
      return null;
    }
    return _fetchUserByEmail(email);
  }

  /// Autentica a un conductor por licencia + contraseña.
  Future<Conductor?> loginConductor(String licencia, String password) async {
    final found = await _conductorByLicencia(licencia);
    if (found == null) return null;
    try {
      await _auth.signInWithEmailAndPassword(
          email: found.email, password: password);
    } catch (_) {
      return null;
    }
    return _conductorFromMap(found.conductor);
  }

  /// Registra un pasajero en Auth + Firestore.
  Future<app.User?> registerPasajero({
    required String nombre,
    required String apellido,
    required String ci,
    required String email,
    required String password,
    required String tipo,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (_) {
      return null;
    }
    final nextId = await _nextId(_usersCollection);
    final doc = {
      'id': nextId,
      'nombre': nombre,
      'apellido': apellido,
      'ci': ci,
      'email': email,
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

  /// Cierra sesión en Firebase.
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Ignorar
    }
  }

  // =====================================================================
  // DATOS DE USUARIO / PASAJERO
  // =====================================================================

  Future<app.User?> _fetchUserByEmail(String email) async {
    final snap = await _db
        .collection(_usersCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _userFromMap(snap.docs.first.data());
  }

  /// Devuelve el User pasajero con la sesión activa en Firebase.
  Future<app.User?> currentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchUserByEmail(user.email ?? '');
  }

  /// Incrementa (o resta si `delta` es negativo) los puntos del usuario.
  Future<void> addPuntos(String email, int delta) async {
    final q = await _db
        .collection(_usersCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return;
    final ref = q.docs.first.reference;
    final current = (q.docs.first.data()['puntos'] as num?)?.toInt() ?? 0;
    await ref.update({'puntos': current + delta});
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
    final email = userDoc.data()?['email'] as String?;

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
    if (email != null) {
      await addPuntos(email, puntos);
    }
  }

  /// Registra el pago de un viaje y descuenta los puntos del pasajero.
  Future<({bool ok, String message})> pagarViaje({
    required int userId,
    required int conductorId,
    required int puntos,
    required String metodoPago,
  }) async {
    final userDoc = await _db
        .collection(_usersCollection)
        .doc('u-$userId')
        .get();
    if (!userDoc.exists) {
      return (ok: false, message: 'Usuario no encontrado');
    }
    final data = userDoc.data()!;
    final saldo = (data['puntos'] as num?)?.toInt() ?? 0;
    if (saldo < puntos) {
      return (ok: false, message: 'Saldo insuficiente');
    }
    final email = data['email'] as String?;

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
    };
    await _db.collection(_transaccionesCollection).doc('c-$nextId').set(cobro);
    if (email != null) {
      await addPuntos(email, -puntos);
    }
    return (ok: true, message: 'Viaje pagado');
  }

  // =====================================================================
  // CONDUCTOR
  // =====================================================================

  Conductor _conductorFromMap(Map<String, dynamic> m) {
    return Conductor(
      id: (m['id'] as num).toInt(),
      nombre: m['nombre'] as String,
      apellido: m['apellido'] as String,
      ci: m['ci'] as String,
      licencia: m['licencia'] as String,
      telefono: m['telefono'] as String?,
      estado: m['estado'] as String,
    );
  }

  /// Registra un viaje cobrado por un conductor y descuenta puntos si el
  /// pasajero está vinculado.
  Future<({bool ok, String message})> registrarCobro({
    required int conductorId,
    required String tipoUsuario,
    required int puntos,
    required String metodoPago,
    int? userId,
  }) async {
    if (userId != null) {
      final res = await pagarViaje(
          userId: userId,
          conductorId: conductorId,
          puntos: puntos,
          metodoPago: metodoPago);
      if (!res.ok) return res;
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
        'nombre': await _nombreByUserId(userId),
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
      ci: m['ci'] as String,
      email: m['email'] as String,
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
