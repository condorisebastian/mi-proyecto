import 'package:flutter/material.dart';

/// Un único acceso principal a pagos y una sección independiente de carnet.
class PassengerNavigationBar extends StatelessWidget {
  const PassengerNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _labels = ['Inicio', 'Mi carnet', 'Pagar', 'Perfil'];
  static const _icons = [
    Icons.home_outlined,
    Icons.badge_outlined,
    Icons.qr_code_scanner,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_labels.length, (index) {
            final selected = currentIndex == index;
            final central = index == 2;
            final color = selected || central
                ? scheme.primary
                : scheme.onSurfaceVariant;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                child: InkWell(
                  key: ValueKey('passenger-tab-$index'),
                  onTap: () => onSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 56,
                          child: Center(
                            child: central
                                ? Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      borderRadius: BorderRadius.circular(18),
                                      border: selected
                                          ? Border.all(
                                              color: scheme.onPrimary,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          _icons[index],
                                          color: scheme.onPrimary,
                                          size: 30,
                                        ),
                                        if (index == 2)
                                          Positioned(
                                            right: 3,
                                            bottom: 3,
                                            child: Icon(
                                              Icons.contactless,
                                              color: scheme.onPrimary,
                                              size: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                : AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? scheme.primaryContainer
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      _icons[index],
                                      color: color,
                                      size: 24,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color,
                            fontSize: 10.5,
                            height: 1.2,
                            fontWeight: selected || central
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
