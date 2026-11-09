import 'package:flutter/material.dart';

import '../screens/city_selection_screen.dart';
import '../services/app_preferences.dart';

/// Solicita ciudad tras cada acceso y cuando una sesión restaurada no tiene una.
class CityGate extends StatefulWidget {
  const CityGate({
    super.key,
    required this.child,
    this.confirmOnEntry = false,
    this.preferences,
  });

  final Widget child;
  final bool confirmOnEntry;
  final AppPreferences? preferences;

  @override
  State<CityGate> createState() => _CityGateState();
}

class _CityGateState extends State<CityGate> {
  bool _ready = false;
  bool _needsCity = true;
  AppPreferences get _preferences =>
      widget.preferences ?? AppPreferences.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _preferences.load();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _needsCity = widget.confirmOnEntry || _preferences.city == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_needsCity) return widget.child;
    return CitySelectionScreen(
      preferences: _preferences,
      allowBack: false,
      onSelected: (_) => setState(() => _needsCity = false),
    );
  }
}
