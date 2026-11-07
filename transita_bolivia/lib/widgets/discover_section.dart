import 'package:flutter/material.dart';

class DiscoverSection extends StatelessWidget {
  const DiscoverSection({
    super.key,
    required this.onRecharge,
    required this.onRechargeAnother,
  });

  final VoidCallback onRecharge;
  final VoidCallback onRechargeAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descubre más',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth * 0.9)
                .clamp(0.0, 420.0)
                .toDouble();
            return SizedBox(
              height: width / 1.5,
              child: ListView.separated(
                key: const ValueKey('discover-carousel'),
                scrollDirection: Axis.horizontal,
                itemCount: 2,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: width,
                  child: Semantics(
                    button: true,
                    label: index == 0
                        ? 'Recárgate puntos'
                        : 'Recarga puntos a otras personas',
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: Ink.image(
                        image: AssetImage(
                          index == 0
                              ? 'assets/images/descubre_recarga.png'
                              : 'assets/images/descubre_recarga_otros.png',
                        ),
                        fit: BoxFit.contain,
                        child: InkWell(
                          key: ValueKey(
                            index == 0 ? 'discover-self' : 'discover-another',
                          ),
                          onTap: index == 0 ? onRecharge : onRechargeAnother,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
