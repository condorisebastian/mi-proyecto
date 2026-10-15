import 'package:cloud_firestore/cloud_firestore.dart';

class ChatIdentity {
  const ChatIdentity({
    required this.canal,
    required this.id,
    required this.nombre,
  });
  final String canal;
  final int id;
  final String nombre;
  bool get isDriver => canal == 'conductor';
  String get chatId => '${isDriver ? 'c' : 'p'}-$id';
  String get operation => isDriver ? 'retiro' : 'recarga';
}

class FinancialRequest {
  const FinancialRequest({
    required this.id,
    required this.chatId,
    required this.ownerId,
    required this.canal,
    required this.monto,
    required this.estado,
    required this.detalle,
    required this.dia,
  });
  final String id;
  final String chatId;
  final int ownerId;
  final String canal;
  final int monto;
  final String estado;
  final String detalle;
  final String dia;
  bool get isWithdrawal => canal == 'conductor';
  bool get pending => estado == 'pendiente';
  String get statusLabel => switch (estado) {
    'aprobada' => 'Confirmada',
    'rechazada' => 'Rechazada',
    _ => 'Pendiente',
  };
  factory FinancialRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FinancialRequest(
      id: doc.id,
      chatId: data['chat_id'] as String,
      ownerId: (data['id_cliente'] as num).toInt(),
      canal: data['canal'] as String,
      monto: (data['monto'] as num).toInt(),
      estado: data['estado'] as String,
      detalle: data['detalle'] as String? ?? '',
      dia: data['dia'] as String? ?? '',
    );
  }
}

class WithdrawalBalance {
  const WithdrawalBalance({
    this.ingresos = 0,
    this.reservado = 0,
    this.retirado = 0,
  });
  final int ingresos;
  final int reservado;
  final int retirado;
  int get disponible => (ingresos - reservado - retirado).clamp(0, ingresos);
}

class ChatFailure implements Exception {
  const ChatFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
