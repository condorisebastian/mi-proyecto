import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/driver_auth_service.dart';
import 'services/driver_api_service.dart';
import 'services/admin_auth_service.dart';
import 'services/firebase_service.dart' as fb;
import 'config.dart';
import 'theme.dart';
import 'firebase_options.dart';
import 'screens/passenger/role_selection_screen.dart';
import 'screens/passenger/requirements_screen.dart';
import 'screens/passenger/user_type_screen.dart';
import 'screens/passenger/login_screen.dart';
import 'screens/passenger/register_screen.dart';
import 'screens/passenger/home_screen.dart';
import 'screens/driver/login_screen.dart' as driver_login;
import 'screens/driver/register_screen.dart' as driver_register;
import 'screens/driver/home_screen.dart' as driver_home;
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_home_screen.dart';

/// Identidad mínima de la app frente a Firestore (login anónimo).
/// Mientras el acceso sea por PIN (sin Firebase Auth), esto permite que las
/// reglas exijan `request.auth != null` en lugar de permitir acceso abierto.
Future<void> _ensureFirebaseIdentity() async {
  if (!AppConfig.useFirebase) return;
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (_) {
    // Sin identidad anónima la app sigue leyendo si las reglas lo permiten.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _ensureFirebaseIdentity();

  if (AppConfig.useFirebase) {
    await fb.FirebaseService.instance.ensureAdminUser();
  }

  final auth = AuthService();
  await auth.restoreSession();
  ApiService.tokenProvider = () => auth.token;

  final driverAuth = DriverAuthService();
  await driverAuth.restoreSession();
  DriverApiService.tokenProvider = () => driverAuth.token;

  final adminAuth = AdminAuthService();
  await adminAuth.restoreSession();

  runApp(TransitaBoliviaApp(
    auth: auth,
    driverAuth: driverAuth,
    adminAuth: adminAuth,
  ));
}

class TransitaBoliviaApp extends StatelessWidget {
  const TransitaBoliviaApp({
    super.key,
    required this.auth,
    required this.driverAuth,
    required this.adminAuth,
  });

  final AuthService auth;
  final DriverAuthService driverAuth;
  final AdminAuthService adminAuth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: driverAuth),
        ChangeNotifierProvider.value(value: adminAuth),
      ],
      child: MaterialApp(
        title: 'Transita Bolivia',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: auth.isLoggedIn
            ? '/passenger/home'
            : driverAuth.isLoggedIn
                ? '/driver/home'
                : '/',
        routes: {
          '/': (context) => const RoleSelectionScreen(),
          '/passenger/requirements': (context) =>
              const RequirementsScreen(),
          '/passenger/type': (context) => const UserTypeScreen(),
          '/passenger/login': (context) => const LoginScreen(),
          '/passenger/register': (context) => const RegisterScreen(),
          '/passenger/home': (context) => const HomeScreen(),
          '/driver/login': (context) => const driver_login.DriverLoginScreen(),
          '/driver/register': (context) => const driver_register.DriverRegisterScreen(),
          '/driver/home': (context) => const driver_home.DriverHomeScreen(),
          '/admin/login': (context) => const AdminLoginScreen(),
          '/admin/home': (context) => const AdminHomeScreen(),
        },
      ),
    );
  }
}
