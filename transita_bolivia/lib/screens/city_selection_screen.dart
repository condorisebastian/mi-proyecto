import 'package:flutter/material.dart';

import '../data/cities.dart';
import '../services/app_preferences.dart';
import '../widgets/login_progress_indicator.dart';

class CitySelectionScreen extends StatefulWidget {
  const CitySelectionScreen({
    super.key,
    required this.onSelected,
    this.preferences,
    this.allowBack = true,
  });

  final ValueChanged<String> onSelected;
  final AppPreferences? preferences;
  final bool allowBack;

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _city;
  bool _saving = false;
  AppPreferences get _preferences =>
      widget.preferences ?? AppPreferences.instance;

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: _preferences.city ?? '');
    _restore();
  }

  Future<void> _restore() async {
    await _preferences.load();
    if (mounted && _city.text.isEmpty) {
      setState(() => _city.text = _preferences.city ?? '');
    }
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving || !_form.currentState!.validate()) return;
    final city = normalizeCity(_city.text)!;
    setState(() => _saving = true);
    try {
      await _preferences.setCity(city);
      if (mounted) widget.onSelected(city);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar tu ciudad. Inténtalo nuevamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu ciudad'),
        automaticallyImplyLeading: widget.allowBack,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.location_city_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¿En qué ciudad estás?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Elige dónde vas a usar Transita Bolivia. Puedes cambiar tu ciudad después desde Inicio.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('city-input'),
                    controller: _city,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 60,
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _continue(),
                    decoration: const InputDecoration(
                      labelText: 'Ciudad o municipio',
                      hintText: 'Ej. Santa Cruz de la Sierra',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      helperText: 'También puedes escribir otra ciudad.',
                      helperMaxLines: 3,
                    ),
                    validator: (value) => normalizeCity(value ?? '') == null
                        ? 'Escribe una ciudad de 2 a 60 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ciudades frecuentes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestedCities
                        .map(
                          (city) => ChoiceChip(
                            label: Text(city),
                            selected: _city.text.trim() == city,
                            onSelected: _saving
                                ? null
                                : (_) {
                                    setState(() => _city.text = city);
                                    FocusScope.of(context).unfocus();
                                  },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: ElevatedButton(
          key: const ValueKey('city-continue'),
          onPressed: _saving || normalizeCity(_city.text) == null
              ? null
              : _continue,
          child: _saving
              ? const LoginProgressIndicator()
              : const Text('CONTINUAR'),
        ),
      ),
    );
  }
}
