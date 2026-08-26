import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
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
  final auth = AuthService();
  await auth.restoreSession();
  ApiService.tokenProvider = () => auth.token;
  runApp(TransitaBoliviaApp(auth: auth));
}

class TransitaBoliviaApp extends StatelessWidget {
  const TransitaBoliviaApp({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: auth,
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
        initialRoute: auth.isLoggedIn ? '/home' : '/',
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
