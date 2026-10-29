import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class CardProof {
  CardProof({required this.uid, required this.counter, required this.mac});
  final String uid;
  final String counter;
  final String mac;
  static CardProof? tryParse(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 4 ||
        parts[0] != 'TRANSITA1' ||
        !RegExp(r'^[0-9a-fA-F]{14}$').hasMatch(parts[1]) ||
        !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(parts[2]) ||
        !RegExp(r'^[0-9a-fA-F]{16}$').hasMatch(parts[3])) {
      return null;
    }
    return CardProof(uid: parts[1], counter: parts[2], mac: parts[3]);
  }

  Map<String, String> toJson() => {'uid': uid, 'counter': counter, 'mac': mac};
}

class PosService {
  static const enabled = bool.fromEnvironment(
    'ENABLE_POS',
    defaultValue: false,
  );
  Future<void> activate(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  }

  Future<String> charge({
    required CardProof card,
    required int conductorId,
    required int amountCents,
    required int quantity,
    required String reference,
    String? routeId,
  }) async {
    if (!enabled) {
      throw StateError(
        'Terminal pendiente de activación. Contacta al responsable de Transita Bolivia.',
      );
    }
    final auth = FirebaseAuth.instance.currentUser;
    if (auth == null || auth.isAnonymous) {
      throw StateError('Activa la sesión de esta terminal para cobrar.');
    }
    final result =
        await FirebaseFunctions.instanceFor(
          region: 'southamerica-east1',
        ).httpsCallable('authorizeCardPayment').call<Map<String, dynamic>>({
          'proof': card.toJson(),
          'conductorId': conductorId,
          'amountCents': amountCents,
          'quantity': quantity,
          'reference': reference,
          'routeId': ?routeId,
        });
    if (result.data['ok'] != true || result.data['receipt'] is! String) {
      throw StateError(
        'No se confirmó el cobro. Consulta su estado antes de repetirlo.',
      );
    }
    return result.data['receipt'] as String;
  }
}
