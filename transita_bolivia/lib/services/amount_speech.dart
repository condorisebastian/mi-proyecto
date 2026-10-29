import 'package:flutter_tts/flutter_tts.dart';
import '../models/money.dart';

class AmountSpeech {
  AmountSpeech([this._engine]);
  static final instance = AmountSpeech();
  FlutterTts? _engine;
  int _request = 0;

  static String describe(num amount, {String label = 'Importe'}) {
    if (!Money.valid(amount) || amount < 0) {
      throw ArgumentError('Importe inválido');
    }
    final cents = Money.cents(amount);
    final whole = cents ~/ 100;
    final fraction = cents % 100;
    return '$label: $whole ${whole == 1 ? 'boliviano' : 'bolivianos'}'
        '${fraction == 0 ? '' : ' con $fraction ${fraction == 1 ? 'centavo' : 'centavos'}'}.';
  }

  Future<bool> speak(num amount, {String label = 'Importe'}) async {
    final request = ++_request;
    final words = describe(amount, label: label);
    try {
      final engine = _engine ??= FlutterTts();
      await engine.stop();
      var spanish = false;
      for (final language in ['es-BO', 'es-ES', 'es-MX', 'es']) {
        if (await engine.isLanguageAvailable(language) == true) {
          await engine.setLanguage(language);
          spanish = true;
          break;
        }
      }
      if (!spanish) return false;
      await engine.setSpeechRate(0.45);
      if (request != _request) return true;
      return await engine.speak(words) == 1;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    _request++;
    try {
      await _engine?.stop();
    } catch (_) {
      /* Motor opcional. */
    }
  }
}
