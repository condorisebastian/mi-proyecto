import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/profile_photo_store.dart';
import '../../widgets/profile_photo_avatar.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key, required this.userId, this.store});
  final int userId;
  final ProfilePhotoStore? store;
  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  ProfilePhotoStore get _store => widget.store ?? ProfilePhotoStore.instance;
  bool _busy = false;
  String? _error;

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store.beginSelection(widget.userId);
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (!mounted || image == null) return;
      if (await image.length() > ProfilePhotoStore.maximumBytes) {
        throw const FormatException('La imagen supera 5 MB.');
      }
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      await _store.save(widget.userId, bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar la foto. Elige una imagen de hasta 5 MB.',
        );
      }
    } finally {
      await _store.finishSelection(widget.userId);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store.remove(widget.userId);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo quitar la foto. Reintenta.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Foto de perfil')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ProfilePhotoAvatar(
                    userId: widget.userId,
                    radius: 64,
                    store: _store,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Elige cómo te ven en Mi Pasaje',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu foto se guarda en este teléfono para esta cuenta. '
                  'Puedes cambiarla o quitarla cuando quieras.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _choose,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Elegir imagen'),
                ),
                if (_store.pathFor(widget.userId) != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _remove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar foto'),
                  ),
                ],
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
