class Transaction {
  final int id;
  final int? idUsuario;
  final int idConductor;
  final int puntos;
  final String tipo;
  final String metodoPago;
  final String estado;
  final DateTime fecha;

  Transaction({
    required this.id,
    this.idUsuario,
    required this.idConductor,
    required this.puntos,
    required this.tipo,
    required this.metodoPago,
    required this.estado,
    required this.fecha,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      idUsuario: json['id_usuario'],
      idConductor: json['id_conductor'],
      puntos: json['puntos'],
      tipo: json['tipo'],
      metodoPago: json['metodo_pago'],
      estado: json['estado'],
      fecha: DateTime.parse(json['fecha']),
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
    };
  }

  String get tipoDisplay {
    switch (tipo) {
      case 'cobro_viaje':
        return '🚌 Viaje';
      case 'recarga':
        return '💳 Recarga';
      default:
        return tipo;
    }
  }

  String get metodoPagoDisplay {
    switch (metodoPago) {
      case 'tarjeta_nfc':
        return '📱 NFC';
      case 'qr':
        return '📷 QR';
      case 'recarga':
        return '💳 Recarga';
      default:
        return metodoPago;
    }
  }
}
