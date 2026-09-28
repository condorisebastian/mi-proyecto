import 'package:flutter/material.dart';
import '../../theme.dart';
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.background,
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
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Elige tu perfil y escribe tu PIN',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'estudiante',
                              icon: Icon(Icons.school, size: 18),
                              label: Text('Estudiante',
                                  style: TextStyle(fontSize: 10)),
                            ),
                            ButtonSegment(
                              value: 'civil',
                              icon: Icon(Icons.person, size: 18),
                              label: Text('Ciudadano',
                                  style: TextStyle(fontSize: 10)),
                            ),
                            ButtonSegment(
                              value: 'adulto_mayor',
                              icon: Icon(Icons.elderly, size: 18),
                              label: Text('Adulto mayor',
                                  style: TextStyle(fontSize: 10)),
                            ),
                            ButtonSegment(
                              value: 'discapacitado',
                              icon: Icon(Icons.accessible, size: 18),
                              label: Text('Con discapacidad',
                                  style: TextStyle(fontSize: 10)),
                            ),
                          ],
                          selected: {_tipo},
                          showSelectedIcon: false,
                          multiSelectionEnabled: false,
                          onSelectionChanged: (selection) {
                            setState(() => _tipo = selection.first);
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity(horizontal: -3),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _ciController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          decoration: InputDecoration(
                            labelText: 'Nro. de Carnet (CI) — opcional',
                            prefixIcon: const Icon(Icons.badge),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Solo ingresa el CI si lo recuerdas; con el PIN basta.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                authService.lastLoginError ??
                                                    'PIN o carnet incorrectos'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
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
                            style: TextStyle(color: AppColors.primary),
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
