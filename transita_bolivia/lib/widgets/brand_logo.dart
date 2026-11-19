import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 180});

  final double width;
  static const assetPath = 'assets/images/logo_app_new.png';

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.asset(
      assetPath,
      width: width,
      height: width,
      fit: BoxFit.cover,
      semanticLabel: 'Mi Pasaje',
    ),
  );
}
