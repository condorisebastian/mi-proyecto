import 'money.dart';

class Transaction {
  final int id;
  final int? idUsuario;
  final int idConductor;
  final num puntos;
  final String tipo;
  final String metodoPago;
  final String estado;
  final DateTime fecha;
  final int cantidadPasajeros;

  Transaction({
    required this.id,
    this.idUsuario,
    required this.idConductor,
    required this.puntos,
    required this.tipo,
    required this.metodoPago,
    required this.estado,
    required this.fecha,
    this.cantidadPasajeros = 1,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      idUsuario: json['id_usuario'],
      idConductor: json['id_conductor'],
      puntos: Money.read(json['puntos']),
      tipo: json['tipo'],
      metodoPago: json['metodo_pago'],
      estado: json['estado'],
      fecha: DateTime.parse(json['fecha']),
      cantidadPasajeros: (json['cantidad_pasajeros'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_usuario': idUsuario,
      'id_conductor': idConductor,
      'puntos': puntos,
      'tipo': tipo,
      'metodo_pago': metodoPago,
      'estado': estado,
      'fecha': fecha.toIso8601String(),
      'cantidad_pasajeros': cantidadPasajeros,
    };
  }

  String get tipoDisplay {
    switch (tipo) {
      case 'cobro_viaje':
        return cantidadPasajeros > 1
            ? 'Viaje · $cantidadPasajeros pasajes'
            : 'Viaje';
      case 'recarga':
        return 'Recarga';
      case 'retiro_conductor':
        return 'Retiro';
      default:
        return tipo;
    }
  }

  String get metodoPagoDisplay {
    switch (metodoPago) {
      case 'qr':
        return 'QR';
      case 'recarga':
        return 'Recarga';
      case 'chat':
        return 'Chat de atención';
      default:
        return 'Otro método';
    }
  }
}
