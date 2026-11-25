import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../services/profile_photo_store.dart';

class ProfilePhotoAvatar extends StatefulWidget {
  const ProfilePhotoAvatar({
    super.key,
    required this.userId,
    this.radius = 30,
    this.store,
  });
  final int userId;
  final double radius;
  final ProfilePhotoStore? store;

  @override
  State<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends State<ProfilePhotoAvatar> {
  ProfilePhotoStore get _store => widget.store ?? ProfilePhotoStore.instance;
  @override
  void initState() {
    super.initState();
    unawaited(_store.load(widget.userId));
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.store != widget.store) {
      unawaited(_store.load(widget.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Icons.person_outline_rounded,
      size: widget.radius,
      color: scheme.onPrimaryContainer,
    );
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final path = _store.pathFor(widget.userId);
        return Semantics(
          label: 'Foto de perfil',
          image: true,
          child: CircleAvatar(
            radius: widget.radius,
            backgroundColor: scheme.primaryContainer,
            child: path == null
                ? placeholder
                : ClipOval(
                    child: Image.file(
                      File(path),
                      width: widget.radius * 2,
                      height: widget.radius * 2,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
