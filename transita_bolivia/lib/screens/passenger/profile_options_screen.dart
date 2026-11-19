import 'package:flutter/material.dart';
import '../../models/money.dart';
import '../../models/user.dart';
import '../../services/payment_preferences.dart';

typedef ProfileSupport = void Function(String type, String description);

class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(20), children: children),
      ),
    ),
  );
}

class PersonalDataScreen extends StatelessWidget {
  const PersonalDataScreen({super.key, required this.user});
  final User user;
  @override
  Widget build(BuildContext context) => ProfileDetailScreen(
    title: 'Mis datos',
    children: [
      for (final entry in {
        'Nombres y apellidos': '${user.nombre} ${user.apellido}'.trim(),
        'ID de usuario': '#${user.id}',
        'Carnet de identidad (CI)': user.ci,
        'Tipo de pasajero': user.tipoDisplay,
        'Correo electrónico': user.email,
      }.entries)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SelectableText(
                  entry.value.trim().isEmpty ? 'No registrado' : entry.value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        'Contacta al centro de atención si necesitas corregir tus datos.',
      ),
    ],
  );
}

class AttentionPointsScreen extends StatelessWidget {
  const AttentionPointsScreen({super.key, required this.onSupport});
  final ProfileSupport onSupport;
  @override
  Widget build(BuildContext context) => ProfileDetailScreen(
    title: 'Puntos de atención',
    children: [
      const Icon(Icons.support_agent_rounded, size: 64),
      const SizedBox(height: 20),
      const Text(
        'Estamos para ayudarte',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Card(
        child: ListTile(
          leading: Icon(Icons.chat_bubble_outline_rounded),
          title: Text('Centro de atención en la app'),
          subtitle: Text(
            'Consulta tus recargas, pagos, clave y tarjeta desde Ayuda y soporte.',
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Atención presencial',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Todavía no hay direcciones y horarios verificados en el catálogo. Consulta al operador antes de desplazarte.',
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => onSupport(
          'otro',
          'Quiero consultar los puntos de atención y recarga disponibles, sus direcciones y horarios.',
        ),
        icon: const Icon(Icons.support_agent),
        label: const Text(
          'Consultar puntos de atención',
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}

class ChangeAccessScreen extends StatelessWidget {
  const ChangeAccessScreen({super.key, required this.onSupport});
  final ProfileSupport onSupport;
  @override
  Widget build(BuildContext context) => ProfileDetailScreen(
    title: 'Cambiar mi clave',
    children: [
      const Icon(Icons.lock_reset_rounded, size: 64),
      const SizedBox(height: 20),
      const Text(
        'Actualiza tu PIN de acceso',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text(
        'Tu clave de Mi Pasaje es un PIN de cuatro dígitos. El operador puede regenerarlo después de verificar tu identidad.',
      ),
      const SizedBox(height: 16),
      const Text(
        'El cambio se confirma cuando el operador lo realiza. Abrir esta pantalla o enviar una solicitud no modifica tu clave.',
      ),
      const SizedBox(height: 16),
      const Text(
        'No escribas tu PIN actual ni la nueva clave en el mensaje de soporte.',
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => onSupport(
          'pin',
          'Solicito cambiar mi PIN de acceso. Quiero coordinar la verificación de mi identidad con el operador.',
        ),
        icon: const Icon(Icons.support_agent),
        label: const Text(
          'Solicitar cambio de clave',
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}

class PaymentLimitScreen extends StatefulWidget {
  const PaymentLimitScreen({super.key, required this.userId});
  final int userId;
  @override
  State<PaymentLimitScreen> createState() => _PaymentLimitScreenState();
}

class _PaymentLimitScreenState extends State<PaymentLimitScreen> {
  late final _preferences = PaymentPreferences(widget.userId);
  final _amount = TextEditingController();
  bool _loading = true, _enabled = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _preferences.load();
      if (!mounted) return;
      final cents = _preferences.limitCents;
      setState(() {
        _enabled = cents != null;
        _amount.text = cents == null ? '' : Money.format(cents / 100);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo leer tu configuración.';
        });
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amount.text);
    if (_enabled && (amount == null || amount <= 0)) {
      setState(
        () => _error =
            'Introduce un monto mayor a cero, con hasta dos decimales.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _preferences.setLimit(_enabled ? amount : null);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Límite de pago guardado.')));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar el límite. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileDetailScreen(
    title: 'Establecer montos límites',
    children: _loading
        ? [const Center(child: CircularProgressIndicator())]
        : [
            const Icon(Icons.tune_rounded, size: 56),
            const SizedBox(height: 20),
            const Text(
              'Tú eliges el máximo por pago',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Este control se aplica a tus pagos QR desde esta cuenta y este teléfono. No modifica los límites del servidor ni de otros dispositivos.',
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Activar límite por pago'),
              value: _enabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            if (_enabled)
              TextField(
                key: const ValueKey('payment-limit-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto máximo en Bs',
                  prefixText: 'Bs ',
                  helperText: 'Por ejemplo: 3.50 o 8.50.',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar límite'),
            ),
          ],
  );
}

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key, required this.userId});
  final int userId;
  @override
  State<BiometricSettingsScreen> createState() =>
      _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  late final _preferences = PaymentPreferences(widget.userId);
  final _biometrics = PaymentBiometrics();
  bool _enabled = false, _available = false, _busy = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _preferences.load();
      final available = await _biometrics.available();
      if (mounted) {
        setState(() {
          _available = available;
          _enabled = _preferences.biometricEnabled;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'No se pudo leer la configuración.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _change(bool value) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (!await _biometrics.confirm()) {
        if (mounted) {
          setState(
            () => _message =
                'No se confirmó tu identidad. La configuración no cambió.',
          );
        }
        return;
      }
      await _preferences.setBiometric(value);
      if (mounted) {
        setState(() {
          _enabled = value;
          _message = 'Preferencia guardada.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'No se pudo guardar la preferencia.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileDetailScreen(
    title: 'Biometría digital',
    children: [
      const Icon(Icons.fingerprint_rounded, size: 80),
      const SizedBox(height: 20),
      const Text(
        'Confirma tus pagos con tu huella',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text(
        'Usa la huella o biometría registrada en el teléfono antes de cada pago QR. Mi Pasaje no recibe ni guarda tu huella.',
      ),
      const SizedBox(height: 20),
      SwitchListTile(
        key: const ValueKey('biometric-payment-toggle'),
        title: const Text('Confirmación biométrica'),
        subtitle: Text(
          _available
              ? 'Protección adicional para esta cuenta y teléfono.'
              : 'Configura una huella compatible en los ajustes del teléfono y vuelve a comprobar.',
        ),
        value: _enabled,
        onChanged: _busy || (!_available && !_enabled) ? null : _change,
      ),
      if (_busy) const Center(child: CircularProgressIndicator()),
      if (_message != null)
        Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
      const SizedBox(height: 16),
      const Text(
        'Para activar o desactivar esta opción debes confirmar tu identidad. Si cambias la biometría del teléfono, revísala en los ajustes del sistema antes de pagar.',
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () {
                setState(() => _busy = true);
                _load();
              },
        child: const Text('Comprobar disponibilidad'),
      ),
    ],
  );
}

class AppVersionScreen extends StatefulWidget {
  const AppVersionScreen({super.key});
  @override
  State<AppVersionScreen> createState() => _AppVersionScreenState();
}

class _AppVersionScreenState extends State<AppVersionScreen> {
  late final _info = PaymentBiometrics.channel.invokeMapMethod<String, dynamic>(
    'appVersion',
  );
  @override
  Widget build(BuildContext context) => ProfileDetailScreen(
    title: 'Versión de la app',
    children: [
      const Icon(Icons.info_outline_rounded, size: 64),
      const SizedBox(height: 24),
      const Text(
        'Mi Pasaje',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, dynamic>?>(
        future: _info,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('No se pudo consultar la versión instalada.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final info = snapshot.data!;
          return Text(
            'Versión ${info['version']}\nCompilación ${info['build']}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          );
        },
      ),
    ],
  );
}

class LegalInformationScreen extends StatelessWidget {
  const LegalInformationScreen({super.key, this.privacy = false});
  final bool privacy;
  @override
  Widget build(BuildContext context) => ProfileDetailScreen(
    title: privacy ? 'Política de privacidad' : 'Términos y condiciones',
    children: [
      const Text(
        'Mi Pasaje · Versión de demostración',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      Text(
        privacy
            ? 'Datos que utilizamos\nNombre, carnet, tipo de pasajero y datos de cuenta; saldo, pagos, recargas e incidencias para prestar el servicio.\n\n'
                  'Gestión de los datos\nLa cuenta y las operaciones se gestionan en el servicio configurado para la app: Firebase o el backend del operador. Las preferencias de saldo oculto, límite por pago y biometría se guardan en este teléfono.\n\n'
                  'Biometría\nEl sistema del teléfono realiza la verificación. Mi Pasaje recibe su resultado y no almacena huellas ni imágenes biométricas.\n\n'
                  'Carnet de muestra\nLa imagen incluida contiene datos ficticios y no representa un documento personal emitido al usuario.\n\n'
                  'Consultas\nSolicita revisión o corrección de tus datos y consulta su conservación desde Ayuda y soporte. No envíes tu PIN en los mensajes.'
            : 'Uso de tu cuenta\nRevisa tus datos y protege tu PIN. Confirma el conductor, la cantidad de pasajes y el importe antes de autorizar un pago.\n\n'
                  'Saldo y operaciones\nLas recargas requieren confirmación del operador. Los comprobantes corresponden a operaciones registradas y confirmadas. Reporta las diferencias al centro de atención.\n\n'
                  'Tarjeta y carnet\nNFC está pendiente de habilitación. La tarjeta física debe ser emitida y vinculada por el operador. El carnet incluido es una muestra con datos ficticios.\n\n'
                  'Límites personales\nEl máximo por pago es un control de esta cuenta y teléfono, no un límite central de la plataforma.\n\n'
                  'Alcance\nEsta versión sirve para demostración y pruebas. Los destinos sin tarifa verificada no habilitan cobros provinciales. Consulta las condiciones del operador antes de utilizar el servicio en una operación real.',
        style: const TextStyle(fontSize: 16, height: 1.6),
      ),
    ],
  );
}
