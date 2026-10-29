import 'package:intl/intl.dart';
import 'money.dart';
import 'transaction.dart';

/// Solo se crea a partir de movimientos registrados en el historial.
class PaymentReceipt {
  PaymentReceipt._(this.transaction);
  final Transaction transaction;

  static PaymentReceipt? fromTransaction(Transaction transaction) {
    if (transaction.hasPendingWrites ||
        transaction.id == 0 ||
        !['exitoso', 'exitosa'].contains(transaction.estado) ||
        !['cobro_viaje', 'recarga'].contains(transaction.tipo) ||
        !Money.valid(transaction.puntos) ||
        transaction.puntos <= 0 ||
        (transaction.tipo == 'cobro_viaje' &&
            transaction.cantidadPasajeros < 1)) {
      return null;
    }
    return PaymentReceipt._(transaction);
  }

  String get reference => transaction.id.toString();
  String get amount => 'Bs ${Money.format(transaction.puntos)}';
  String get date =>
      DateFormat('dd/MM/yyyy HH:mm:ss').format(transaction.fecha.toLocal());
  String get title =>
      transaction.tipo == 'recarga' ? 'Recarga de saldo' : 'Pago de pasaje';
  Map<String, String> get details => {
    'Operación': reference,
    'Estado': 'Confirmado',
    'Fecha': date,
    if (transaction.tipo == 'cobro_viaje') ...{
      'Conductor': '#${transaction.idConductor}',
      'Pasajes': '${transaction.cantidadPasajeros}',
    },
    'Método': transaction.metodoPagoDisplay,
    'Total': amount,
  };
  String get text =>
      'TRANSITA BOLIVIA\nComprobante de $title\n'
      '${details.entries.map((e) => '${e.key}: ${e.value}').join('\n')}';
}
