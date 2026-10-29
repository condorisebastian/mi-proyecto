import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 220});

  final double width;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.asset(
      'assets/images/logo_transitabolivia.png',
      width: width,
      height: width * 559 / 1024,
      fit: BoxFit.contain,
      semanticLabel: 'Transita Bolivia',
    ),
  );
}
