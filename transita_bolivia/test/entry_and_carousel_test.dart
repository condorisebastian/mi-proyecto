import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transita_bolivia/screens/passenger/login_screen.dart';
import 'package:transita_bolivia/screens/driver/login_screen.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/driver_auth_service.dart';
import 'package:transita_bolivia/theme.dart';
import 'package:transita_bolivia/widgets/discover_section.dart';

class _PassengerLogin extends AuthService {
  @override
  Future<bool> login(String pin, String tipo, {String ci = ''}) async => true;
}

class _DriverLogin extends DriverAuthService {
  @override
  Future<bool> login(String pin, {String ci = ''}) async => true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final driver in [false, true]) {
    testWidgets(
      'el login de ${driver ? 'conductor' : 'pasajero'} entra directamente a Inicio',
      (tester) async {
        final app = MaterialApp(
          theme: buildAppTheme(),
          home: driver ? const DriverLoginScreen() : const LoginScreen(),
          onGenerateRoute: (settings) {
            expect(settings.name, driver ? '/driver/home' : '/passenger/home');
            expect(settings.arguments, isNull);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Panel de usuario')),
            );
          },
        );
        await tester.pumpWidget(
          driver
              ? ChangeNotifierProvider<DriverAuthService>(
                  create: (_) => _DriverLogin(),
                  child: app,
                )
              : ChangeNotifierProvider<AuthService>(
                  create: (_) => _PassengerLogin(),
                  child: app,
                ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).last, '1234');
        await tester.ensureVisible(find.text('INICIAR SESIÓN'));
        await tester.tap(find.text('INICIAR SESIÓN'));
        await tester.pumpAndSettle();
        expect(find.text('Panel de usuario'), findsOneWidget);
      },
    );
  }

  Widget carousel({
    bool reducedMotion = false,
    bool visible = true,
    List<int>? taps,
    GlobalKey<NavigatorState>? navigator,
  }) => MaterialApp(
    navigatorKey: navigator,
    theme: buildAppTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TickerMode(
          enabled: visible,
          child: DiscoverSection(
            onRecharge: () => taps?.add(0),
            onRechargeAnother: () => taps?.add(1),
            onCheckBalance: () => taps?.add(2),
            onPayWithCard: () => taps?.add(3),
          ),
        ),
      ),
    ),
  );

  int page(WidgetTester tester, {bool offstage = false}) => tester
      .widget<PageView>(
        find.byKey(
          const ValueKey('discover-carousel'),
          skipOffstage: !offstage,
        ),
      )
      .controller!
      .page!
      .round();

  testWidgets(
    'las cuatro ilustraciones avanzan solas, vuelven al inicio y pueden pausarse',
    (tester) async {
      await tester.pumpWidget(carousel());
      await tester.pump();
      expect(page(tester), 0);
      for (var next = 1; next <= 4; next++) {
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 650));
        expect(page(tester), next);
      }
      expect(find.byKey(const ValueKey('discover-self')), findsWidgets);
      await tester.tap(find.byTooltip('Pausar carrusel'));
      await tester.pump();
      final paused = page(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(page(tester), paused);
      await tester.tap(find.byTooltip('Reanudar carrusel'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 650));
      expect(page(tester), paused + 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movimiento reducido conserva acceso manual a las cuatro acciones',
    (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(carousel(reducedMotion: true, taps: taps));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 12));
      expect(page(tester), 0);
      for (var index = 0; index < 4; index++) {
        await tester.ensureVisible(find.byKey(ValueKey('discover-dot-$index')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('discover-dot-$index')));
        await tester.pumpAndSettle();
        final key = [
          'discover-self',
          'discover-another',
          'discover-balance',
          'discover-card',
        ][index];
        await tester.ensureVisible(find.byKey(ValueKey(key)).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)).first);
        await tester.pumpAndSettle();
      }
      expect(taps, [0, 1, 2, 3]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'el carrusel no avanza detrás de otra pantalla y reanuda al volver',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(carousel(navigator: navigator));
      await tester.pump();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Otra pantalla')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 9));
      expect(page(tester, offstage: true), 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 650));
      expect(page(tester), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'el carrusel se pausa en pestañas inactivas y con la app en segundo plano',
    (tester) async {
      await tester.pumpWidget(carousel(visible: false));
      await tester.pump(const Duration(seconds: 10));
      expect(page(tester), 0);
      await tester.pumpWidget(carousel());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(page(tester), 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 650));
      expect(page(tester), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
