import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ciController = TextEditingController();
  final _pinController = TextEditingController();
  String _tipo = 'estudiante';
  bool _obscurePin = true;

  @override
  void dispose() {
    _ciController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && args['tipo'] != null) {
      _tipo = args['tipo'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E88E5),
              Color(0xFFF5F5F5),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Icon(
                          _tipo == 'estudiante'
                              ? Icons.school
                              : _tipo == 'civil'
                                  ? Icons.person
                                  : _tipo == 'adulto_mayor'
                                      ? Icons.elderly
                                      : Icons.accessible,
                          size: 60,
                          color: const Color(0xFF1E88E5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          _tipo.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E88E5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _ciController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          decoration: InputDecoration(
                            labelText: 'Nro. de Carnet (CI)',
                            prefixIcon: const Icon(Icons.badge),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: _obscurePin,
                          decoration: InputDecoration(
                            labelText: 'PIN (4 dígitos)',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePin
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              tooltip: _obscurePin
                                  ? 'Mostrar PIN'
                                  : 'Ocultar PIN',
                              onPressed: () =>
                                  setState(() => _obscurePin = !_obscurePin),
                            ),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length != 4) {
                              return 'Ingrese su PIN de 4 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: authService.isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      final success = await authService.login(
                                        _pinController.text,
                                        _tipo,
                                        ci: _ciController.text.trim(),
                                      );
                                      if (success && context.mounted) {
                                        Navigator.pushReplacementNamed(
                                            context, '/passenger/home');
                                      } else if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Carnet o PIN incorrectos'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: authService.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'INICIAR SESIÓN',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                                context, '/passenger/requirements',
                                arguments: {'role': 'passenger', 'tipo': _tipo});
                          },
                          child: const Text(
                            '¿No tienes cuenta? Regístrate',
                            style: TextStyle(color: Color(0xFF1E88E5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
