import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/province_routes.dart';

/// Preferencias del dispositivo; no almacena identidad, PIN ni saldo.
class AppPreferences extends ChangeNotifier {
  AppPreferences([this._storage]);
  static final instance = AppPreferences();
  SharedPreferences? _storage;
  Future<void>? _loading;
  Future<void>? _writes;
  bool _loaded = false;
  bool _largeText = false;
  bool _highContrast = false;
  bool _readAmounts = false;
  Set<String> _favorites = {};
  bool get largeText => _largeText;
  bool get highContrast => _highContrast;
  bool get readAmounts => _readAmounts;
  Set<String> get favorites => Set.unmodifiable(_favorites);
  bool isFavorite(String id) => _favorites.contains(id);

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _read();
  }

  Future<void> _read() async {
    try {
      final storage = _storage ??= await SharedPreferences.getInstance();
      _largeText = storage.getBool('a11y.large_text') ?? false;
      _highContrast = storage.getBool('a11y.high_contrast') ?? false;
      _readAmounts = storage.getBool('a11y.read_amounts') ?? false;
      final known = provinceRoutes.map((route) => route.id).toSet();
      _favorites = (storage.getStringList('routes.favorites.v1') ?? [])
          .where(known.contains)
          .toSet();
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // El acceso a las pantallas sigue disponible si falla el almacenamiento.
      _loading = null;
    }
  }

  Future<void> _write(Future<void> Function(SharedPreferences) action) {
    final next = (_writes ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
          await load();
          final storage = _storage;
          if (storage == null) throw StateError('Almacenamiento no disponible');
          await action(storage);
          notifyListeners();
        });
    _writes = next;
    void clear() {
      if (identical(_writes, next)) _writes = null;
    }

    next.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace _) => clear(),
    );
    return next;
  }

  Future<void> setLargeText(bool value) => _write((storage) async {
    if (!await storage.setBool('a11y.large_text', value)) {
      throw StateError('No se pudo guardar la preferencia');
    }
    _largeText = value;
  });
  Future<void> setHighContrast(bool value) => _write((storage) async {
    if (!await storage.setBool('a11y.high_contrast', value)) {
      throw StateError('No se pudo guardar la preferencia');
    }
    _highContrast = value;
  });
  Future<void> setReadAmounts(bool value) => _write((storage) async {
    if (!await storage.setBool('a11y.read_amounts', value)) {
      throw StateError('No se pudo guardar la preferencia');
    }
    _readAmounts = value;
  });
  Future<void> toggleFavorite(String id) => _write((storage) async {
    if (!provinceRoutes.any((route) => route.id == id)) {
      throw ArgumentError('Destino desconocido');
    }
    final next = {..._favorites};
    if (!next.remove(id)) next.add(id);
    if (!await storage.setStringList(
      'routes.favorites.v1',
      next.toList()..sort(),
    )) {
      throw StateError('No se pudo guardar el favorito');
    }
    _favorites = next;
  });
}
