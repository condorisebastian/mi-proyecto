import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:transita_bolivia/models/conductor.dart';
import 'package:transita_bolivia/screens/passenger/role_selection_screen.dart';
import 'package:transita_bolivia/screens/passenger/user_type_screen.dart';
import 'package:transita_bolivia/screens/passenger/login_screen.dart';
import 'package:transita_bolivia/screens/passenger/requirements_screen.dart';
import 'package:transita_bolivia/screens/driver/login_screen.dart';
import 'package:transita_bolivia/screens/driver/charge_screen.dart';
import 'package:transita_bolivia/screens/province_routes_screen.dart';
import 'package:transita_bolivia/services/auth_service.dart';
import 'package:transita_bolivia/services/driver_auth_service.dart';
import 'package:transita_bolivia/theme.dart';

// Esta vista reutiliza los widgets originales. No inicializa Firebase ni
// restaura sesiones. El conductor 0 produce QR rechazados por la app real.
class PreviewPassenger extends AuthService {
  bool _busy = false;
  @override
  bool get isLoading => _busy;
  @override
  String? get lastLoginError =>
      'Vista de demostración. Usa el menú superior para explorar las pantallas.';
  @override
  Future<bool> login(String pin, String tipo, {String ci = ''}) async {
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _busy = false;
    notifyListeners();
    return false;
  }
}

class PreviewDriver extends DriverAuthService {
  final _driver = Conductor(
    id: 0,
    nombre: 'Conductor',
    apellido: 'Demo',
    ci: '',
    licencia: '',
    estado: 'activo',
  );
  bool _busy = false;
  @override
  Conductor? get currentConductor => _driver;
  @override
  bool get isLoading => _busy;
  @override
  String? get lastLoginError =>
      'Vista de demostración. Abre Cobrar desde el menú superior.';
  @override
  Future<bool> login(String pin, {String ci = ''}) async {
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _busy = false;
    notifyListeners();
    return false;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => PreviewPassenger()),
        ChangeNotifierProvider<DriverAuthService>(
          create: (_) => PreviewDriver(),
        ),
      ],
      child: MaterialApp(
        title: 'Transita Bolivia · Vista interactiva',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => const PreviewShell(),
      ),
    ),
  );
}

class PreviewShell extends StatefulWidget {
  const PreviewShell({super.key});
  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell> {
  static const _labels = ['Inicio', 'Perfiles', 'Provincias', 'Cobrar'];
  static const _routes = ['/', '/passenger/type', '/provincias', '/cobrar'];
  int _selected = 0;
  int _generation = 0;

  Route<void> _route(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      '/' => const RoleSelectionScreen(),
      '/passenger/type' => const UserTypeScreen(),
      '/passenger/login' => const LoginScreen(),
      '/driver/login' => const DriverLoginScreen(),
      '/passenger/requirements' => const RequirementsScreen(),
      '/provincias' => const ProvinceRoutesScreen(conductorId: 0),
      '/cobrar' => const DriverChargeScreen(),
      _ => const Scaffold(
        body: Center(child: Text('Esta acción requiere la app conectada.')),
      ),
    };
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffedf1f6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Transita Bolivia · Vista interactiva',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('http://127.0.0.1/transita_bolivia_web/'),
                      webOnlyWindowName: '_blank',
                    ),
                    icon: const Icon(Icons.language),
                    label: const Text('Ver página web y carrusel'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _labels.length; i++)
                    ChoiceChip(
                      label: Text(_labels[i]),
                      selected: i == _selected,
                      onSelected: (_) => setState(() {
                        _selected = i;
                        _generation++;
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reiniciar'),
                    onPressed: () => setState(() {
                      _selected = 0;
                      _generation++;
                    }),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'Pantallas reales de Flutter · Demostración sin conexión a cuentas ni saldos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const phoneWidth = 390.0;
                  const phoneHeight = 780.0;
                  final scale = math.min(
                    1.0,
                    math.min(
                      (constraints.maxWidth - 20) / phoneWidth,
                      (constraints.maxHeight - 10) / phoneHeight,
                    ),
                  );
                  final phone = Container(
                    width: phoneWidth,
                    height: phoneHeight,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xff182333),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: const Size(phoneWidth - 16, phoneHeight - 16),
                          padding: EdgeInsets.zero,
                          viewPadding: EdgeInsets.zero,
                          viewInsets: EdgeInsets.zero,
                        ),
                        child: Navigator(
                          key: ValueKey('$_generation'),
                          initialRoute: _routes[_selected],
                          onGenerateRoute: _route,
                          onGenerateInitialRoutes: (_, route) => [
                            _route(RouteSettings(name: route)),
                          ],
                        ),
                      ),
                    ),
                  );
                  return Center(
                    child: SizedBox(
                      width: phoneWidth * scale,
                      height: phoneHeight * scale,
                      child: FittedBox(fit: BoxFit.contain, child: phone),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 5, 12, 10),
              child: Text(
                'Los QR de esta vista no sirven para cobrar. No representa una sesión Android.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xff53616d)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
