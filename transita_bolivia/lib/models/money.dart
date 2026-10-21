/// Importes en bolivianos; los cálculos se realizan en centavos enteros.
abstract final class Money {
  static int cents(num value) {
    if (!value.isFinite || value.abs() > 1000000000) {
      throw const FormatException('Importe no válido');
    }
    final scaled = value * 100;
    final rounded = scaled.round();
    if ((scaled - rounded).abs() > 0.00001) {
      throw const FormatException('El importe admite hasta dos decimales');
    }
    return rounded;
  }

  static double fromCents(int value) => value / 100;

  static double read(Object? value) {
    if (value == null) return 0;
    if (value is num) return fromCents(cents(value));
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      if (!RegExp(r'^-?\d+(?:\.\d{1,2})?$').hasMatch(normalized)) {
        throw const FormatException('Importe no válido');
      }
      return fromCents(cents(num.parse(normalized)));
    }
    throw const FormatException('Importe no válido');
  }

  static double? tryParse(String value) {
    try {
      return read(value);
    } on FormatException {
      return null;
    }
  }

  static bool valid(num value) {
    try {
      cents(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  static double add(num a, num b) => fromCents(cents(a) + cents(b));
  static double subtract(num a, num b) => fromCents(cents(a) - cents(b));
  static double multiply(num amount, int quantity) =>
      fromCents(cents(amount) * quantity);
  static String format(Object? value) => read(value).toStringAsFixed(2);
}
