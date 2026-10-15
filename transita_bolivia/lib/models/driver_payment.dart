class DriverPayment {
  const DriverPayment({
    required this.documentId,
    required this.puntos,
    required this.pasajero,
    required this.fecha,
  });

  final String documentId;
  final int puntos;
  final String pasajero;
  final DateTime fecha;
}

/// Deduplica los avisos aunque Firestore vuelva a emitir la misma instantánea.
/// Los datos de caché y los cobros anteriores a esta sesión no generan alarmas.
class DriverPaymentTracker {
  DriverPaymentTracker({DateTime? since}) : since = since ?? DateTime.now();

  final DateTime since;
  final Set<String> _seen = {};
  bool _receivedServer = false;

  List<DriverPayment> receive(
    Iterable<DriverPayment> payments, {
    required bool fromCache,
  }) {
    if (fromCache) return const [];
    final initialSnapshot = !_receivedServer;
    _receivedServer = true;
    final incoming = <DriverPayment>[];
    for (final payment in payments) {
      if (!_seen.add(payment.documentId)) continue;
      if (!initialSnapshot || !payment.fecha.isBefore(since)) {
        incoming.add(payment);
      }
    }
    incoming.sort((a, b) => a.fecha.compareTo(b.fecha));
    return incoming;
  }
}
