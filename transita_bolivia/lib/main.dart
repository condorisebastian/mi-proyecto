import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/driver_auth_service.dart';
import 'services/driver_api_service.dart';
import 'firebase_options.dart';
import 'screens/passenger/role_selection_screen.dart';
import 'screens/passenger/user_type_screen.dart';
import 'screens/passenger/login_screen.dart';
import 'screens/passenger/register_screen.dart';
import 'screens/passenger/home_screen.dart';
import 'screens/driver/login_screen.dart' as driver_login;
import 'screens/driver/register_screen.dart' as driver_register;
import 'screens/driver/home_screen.dart' as driver_home;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final auth = AuthService();
  await auth.restoreSession();
  ApiService.tokenProvider = () => auth.token;

  final driverAuth = DriverAuthService();
  await driverAuth.restoreSession();
  DriverApiService.tokenProvider = () => driverAuth.token;

  runApp(TransitaBoliviaApp(auth: auth, driverAuth: driverAuth));
}

class TransitaBoliviaApp extends StatelessWidget {
  const TransitaBoliviaApp({
    super.key,
    required this.auth,
    required this.driverAuth,
  });

  final AuthService auth;
  final DriverAuthService driverAuth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: driverAuth),
      ],
      child: MaterialApp(
        title: 'Transita Bolivia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        initialRoute: auth.isLoggedIn
            ? '/passenger/home'
            : driverAuth.isLoggedIn
                ? '/driver/home'
                : '/',
        routes: {
          '/': (context) => const RoleSelectionScreen(),
          '/passenger/type': (context) => const UserTypeScreen(),
          '/passenger/login': (context) => const LoginScreen(),
          '/passenger/register': (context) => const RegisterScreen(),
          '/passenger/home': (context) => const HomeScreen(),
          '/driver/login': (context) => const driver_login.DriverLoginScreen(),
          '/driver/register': (context) => const driver_register.DriverRegisterScreen(),
          '/driver/home': (context) => const driver_home.DriverHomeScreen(),
        },
      ),
    );
  }
}
