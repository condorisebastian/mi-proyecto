import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Fotos privadas de este teléfono, separadas por cuenta y backend.
class ProfilePhotoStore extends ChangeNotifier {
  ProfilePhotoStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  static final instance = ProfilePhotoStore();
  static const maximumBytes = 5 * 1024 * 1024;
  final Future<Directory> Function() _directory;
  final Map<String, String?> _paths = {};
  final Map<String, Future<void>> _loading = {};

  String _account(int userId) {
    if (userId <= 0) throw ArgumentError('Cuenta inválida');
    return '${AppConfig.useFirebase ? 'firebase' : 'api'}-$userId';
  }

  String? pathFor(int userId) => _paths[_account(userId)];
  bool _validName(String name, String account) =>
      RegExp('^${RegExp.escape(account)}-[0-9]+\\.img\$').hasMatch(name);

  Future<Directory> _folder() async {
    final root = await _directory();
    return Directory('${root.path}/profile_photos').create(recursive: true);
  }

  Future<void> load(int userId) {
    final account = _account(userId);
    return _loading.putIfAbsent(account, () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('profile_photo.$account');
        if (name != null && _validName(name, account)) {
          final folder = await _folder();
          final file = File('${folder.path}/$name');
          if (await file.exists() &&
              await file.length() <= maximumBytes &&
              prefs.getString('profile_photo.$account') == name) {
            _paths[account] = file.path;
            notifyListeners();
          }
        }
      } catch (_) {
        // La ausencia de foto nunca impide iniciar sesión ni abrir la app.
      }
    });
  }

  Future<void> save(int userId, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maximumBytes) {
      throw const FormatException('Elige una imagen de hasta 5 MB.');
    }
    // Valida que sea una imagen antes de reemplazar una foto existente.
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1024);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    final account = _account(userId);
    final folder = await _folder();
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString('profile_photo.$account');
    final name = '$account-${DateTime.now().microsecondsSinceEpoch}.img';
    final file = File('${folder.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    if (!await prefs.setString('profile_photo.$account', name)) {
      await file.delete();
      throw StateError('No se pudo guardar la foto.');
    }
    _paths[account] = file.path;
    notifyListeners();
    if (old != null && old != name && _validName(old, account)) {
      try {
        await File('${folder.path}/$old').delete();
      } catch (_) {}
    }
  }

  Future<void> remove(int userId) async {
    final account = _account(userId);
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString('profile_photo.$account');
    if (!await prefs.remove('profile_photo.$account')) {
      throw StateError('No se pudo quitar la foto.');
    }
    _paths.remove(account);
    notifyListeners();
    if (old != null && _validName(old, account)) {
      try {
        final folder = await _folder();
        await File('${folder.path}/$old').delete();
      } catch (_) {}
    }
  }

  Future<void> beginSelection(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('profile_photo.pending', _account(userId))) {
      throw StateError('No se pudo preparar la selección.');
    }
  }

  Future<void> finishSelection(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('profile_photo.pending') == _account(userId)) {
        await prefs.remove('profile_photo.pending');
      }
    } catch (_) {
      /* No bloquea la foto guardada ni el cierre del selector. */
    }
  }

  /// Android puede cerrar la actividad mientras la galería está abierta.
  /// Recupera la selección únicamente para la cuenta que abrió el selector.
  Future<void> recoverPendingSelection(int userId) async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('profile_photo.pending') != _account(userId)) return;
      final response = await ImagePicker().retrieveLostData();
      final image = response.files?.firstOrNull;
      if (image != null && await image.length() <= maximumBytes) {
        await save(userId, await image.readAsBytes());
      }
    } catch (_) {
      // La selección fallida conserva la foto anterior.
    } finally {
      await finishSelection(userId);
    }
  }
}
