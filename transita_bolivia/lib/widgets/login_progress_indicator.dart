import 'package:flutter/material.dart';

class LoginProgressIndicator extends StatelessWidget {
  const LoginProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Colors.white,
        strokeCap: StrokeCap.round,
      ),
    ),
  );
}
