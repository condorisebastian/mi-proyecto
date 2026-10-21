import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transita_bolivia/services/firebase_service.dart';

void main() {
  test(
    'los errores de acceso no revelan PIN, CI ni el perfil de una cuenta',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirebaseService.forTesting(db);
      await db.collection('usuarios').doc('u-7').set({
        'id': 7,
        'nombre': 'Fixture',
        'apellido': 'Prueba',
        'pin': '1357',
        'ci': 'fixture-ci',
        'tipo': 'civil',
        'rol': 'PASAJERO',
        'estado': 'activo',
        'puntos': 0,
      });
      final missing = await service.loginPasajero('2468', 'civil');
      final wrongType = await service.loginPasajero('1357', 'estudiante');
      final wrongCi = await service.loginPasajero(
        '1357',
        'civil',
        ci: 'otro-ci',
      );
      final missingDriver = await service.loginConductor('2468');
      final missingAdmin = await service.loginAdmin('2468');
      for (final error in [
        missing.error,
        wrongType.error,
        wrongCi.error,
        missingDriver.error,
        missingAdmin.error,
      ]) {
        expect(error, 'Datos de acceso incorrectos.');
        expect(error, isNot(contains('1357')));
        expect(error, isNot(contains('2468')));
        expect(error, isNot(contains('fixture-ci')));
        expect(error, isNot(contains('Civil')));
      }
      expect(
        (await service.loginPasajero(
          '1357',
          'civil',
          ci: 'fixture-ci',
        )).user?.id,
        7,
      );
    },
  );
}
