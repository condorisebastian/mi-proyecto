import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as fixture_image;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/models/passenger_qr.dart';
import 'package:transita_bolivia/models/trip_qr.dart';
import 'package:transita_bolivia/screens/passenger/login_screen.dart';
import 'package:transita_bolivia/screens/passenger/passenger_qr_screen.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/profile_photo_store.dart';
import 'package:transita_bolivia/widgets/app_bootstrap.dart';
import 'package:transita_bolivia/widgets/brand_logo.dart';
import 'package:transita_bolivia/widgets/login_role_icon.dart';

import 'passenger_navigation_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'el primer fotograma se muestra mientras la inicialización espera',
    (tester) async {
      final pending = Completer<void>();
      var ready = 0;
      await tester.pumpWidget(
        AppBootstrap(
          initialize: () => pending.future,
          onReady: () => ready++,
          child: const MaterialApp(home: Text('Pantalla lista')),
        ),
      );
      expect(find.text('Mi Pasaje'), findsOneWidget);
      expect(find.text('Pantalla lista'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Preparando tu viaje…'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Pantalla lista'), findsOneWidget);
      expect(ready, 1);
    },
  );

  testWidgets(
    'un fallo de inicio permite reintentar sin mostrar detalles privados',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        AppBootstrap(
          initialize: () async {
            if (++attempts == 1) {
              throw StateError('detalle_privado_del_proveedor');
            }
          },
          child: const MaterialApp(home: Text('Lista')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('detalle_privado'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Lista'), findsOneWidget);
      expect(attempts, 2);
    },
  );

  test('el QR expira, cambia de nonce y no se interpreta como un cobro', () {
    final now = DateTime.utc(2026, 11, 25, 12);
    final first = PassengerQr.create(42, backend: 'F', now: now);
    final second = PassengerQr.create(42, backend: 'F', now: now);
    expect(first.nonce, isNot(second.nonce));
    final parsed = PassengerQr.tryParse(first.encode(), now: now);
    expect(parsed?.userId, 42);
    expect(parsed?.backend, 'F');
    expect(TripQr.tryParse(first.encode()), isNull);
    expect(PassengerQr.tryParse(first.encode(), now: first.expiresAt), isNull);
    expect(
      PassengerQr.tryParse(first.encode().replaceFirst(':D:', ':P:'), now: now),
      isNull,
    );
    expect(
      PassengerQr.tryParse(
        first.encode(),
        now: now.subtract(const Duration(minutes: 1)),
      ),
      isNull,
    );
  });

  testWidgets('Mi QR desaparece al vencer y se regenera sin descontar saldo', (
    tester,
  ) async {
    final auth = fixture.PassengerAuth();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: const MaterialApp(home: PassengerQrScreen(userId: 42)),
      ),
    );
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('QR vencido'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('regenerate-passenger-qr')));
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(auth.currentUser!.puntos, 42.50);
    await auth.logout();
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('La sesión cambió'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Mi QR se oculta al pasar al segundo plano', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: fixture.PassengerAuth(),
        child: const MaterialApp(home: PassengerQrScreen(userId: 42)),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cada categoría usa su icono en lugar de la imagen del login', (
    tester,
  ) async {
    for (final role in [
      'estudiante',
      'civil',
      'adulto_mayor',
      'discapacitado',
    ]) {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          key: ValueKey(role),
          value: fixture.PassengerAuth(),
          child: MaterialApp(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: RouteSettings(arguments: {'tipo': role}),
              builder: (_) => const LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('login-role-$role')), findsOneWidget);
      expect(find.byIcon(LoginRoleIcon.iconFor(role)), findsOneWidget);
      expect(find.byType(BrandLogo), findsNothing);
    }
  });

  // Imagen de un píxel generada como dato de prueba, sin imágenes personales.
  final image = Uint8List.fromList(
    fixture_image.encodePng(fixture_image.Image(width: 1, height: 1)),
  );

  test('la foto persiste por cuenta y quitar una no afecta a otra', () async {
    final directory = await Directory.systemTemp.createTemp('mi-pasaje-photo-');
    addTearDown(() => directory.delete(recursive: true));
    final store = ProfilePhotoStore(directory: () async => directory);
    addTearDown(store.dispose);
    await store.save(42, image);
    await store.save(43, image);
    final other = store.pathFor(43)!;
    final restored = ProfilePhotoStore(directory: () async => directory);
    addTearDown(restored.dispose);
    await restored.load(42);
    expect(restored.pathFor(42), store.pathFor(42));
    expect(restored.pathFor(43), isNull);
    await store.remove(42);
    expect(store.pathFor(42), isNull);
    expect(await File(other).exists(), isTrue);
  });

  test(
    'una foto inválida conserva la anterior y no lee rutas de otra cuenta',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mi-pasaje-photo-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ProfilePhotoStore(directory: () async => directory);
      addTearDown(store.dispose);
      await store.save(42, image);
      final previous = store.pathFor(42);
      await expectLater(
        store.save(42, base64Decode('aG9sYQ==')),
        throwsA(anything),
      );
      expect(store.pathFor(42), previous);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'profile_photo.firebase-43',
        previous!.split(Platform.pathSeparator).last,
      );
      await store.load(43);
      expect(store.pathFor(43), isNull);
    },
  );
}
