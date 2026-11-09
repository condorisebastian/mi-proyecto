import 'dart:async';
import 'package:flutter/material.dart';

class DiscoverSection extends StatefulWidget {
  const DiscoverSection({
    super.key,
    required this.onRecharge,
    required this.onRechargeAnother,
    required this.onCheckBalance,
    required this.onPayWithCard,
  });

  final VoidCallback onRecharge;
  final VoidCallback onRechargeAnother;
  final VoidCallback onCheckBalance;
  final VoidCallback onPayWithCard;

  @override
  State<DiscoverSection> createState() => _DiscoverSectionState();
}

class _DiscoverSectionState extends State<DiscoverSection>
    with WidgetsBindingObserver {
  static const _labels = [
    'Recárgate puntos',
    'Recarga puntos a otras personas',
    'Consulta tu saldo',
    'Paga con tu tarjeta',
  ];
  static const _assets = [
    'descubre_recarga.png',
    'descubre_recarga_otros.png',
    'descubre_saldo.png',
    'descubre_pago_tarjeta.png',
  ];
  static const _keys = [
    'discover-self',
    'discover-another',
    'discover-balance',
    'discover-card',
  ];
  final _pages = PageController(viewportFraction: 0.94);
  Timer? _timer;
  int _current = 0;
  bool _paused = false;
  bool _foreground = true;
  bool _dragging = false;
  bool _animating = false;
  bool _motionAllowed = true;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed = !MediaQuery.disableAnimationsOf(context);
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  void _syncTimer({bool reset = false}) {
    final enabled =
        _motionAllowed && _visible && _foreground && !_paused && !_dragging;
    if (!enabled || reset) {
      _timer?.cancel();
      _timer = null;
    }
    if (enabled && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _advance());
    }
  }

  Future<void> _advance() async {
    if (!mounted || !_pages.hasClients || _animating || _dragging) return;
    _animating = true;
    try {
      await _pages.animateToPage(
        (_pages.page ?? 0).round() + 1,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _animating = false;
    }
  }

  void _goTo(int index) {
    if (!_pages.hasClients) return;
    final page = (_pages.page ?? 0).round();
    final target = page + (index - _current + _labels.length) % _labels.length;
    if (_motionAllowed) {
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _pages.jumpToPage(target);
    }
    _syncTimer(reset: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actions = [
      widget.onRecharge,
      widget.onRechargeAnother,
      widget.onCheckBalance,
      widget.onPayWithCard,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Descubre más',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: !_motionAllowed
                  ? 'Movimiento reducido por el sistema'
                  : _paused
                  ? 'Reanudar carrusel'
                  : 'Pausar carrusel',
              onPressed: !_motionAllowed
                  ? null
                  : () {
                      setState(() => _paused = !_paused);
                      _syncTimer();
                    },
              icon: Icon(
                _paused || !_motionAllowed
                    ? Icons.play_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
              ),
              color: scheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth * 0.94 - 12;
            return SizedBox(
              height: width / 1.5,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth != 0) return false;
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    _dragging = true;
                    _syncTimer();
                  } else if (notification is ScrollEndNotification &&
                      _dragging) {
                    _dragging = false;
                    _syncTimer(reset: true);
                  }
                  return false;
                },
                child: PageView.builder(
                  key: const ValueKey('discover-carousel'),
                  controller: _pages,
                  padEnds: false,
                  onPageChanged: (page) =>
                      setState(() => _current = page % _labels.length),
                  itemBuilder: (context, page) {
                    final index = page % _labels.length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Semantics(
                        button: true,
                        label: _labels[index],
                        child: Material(
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: Ink.image(
                            image: AssetImage(
                              'assets/images/${_assets[index]}',
                            ),
                            fit: BoxFit.contain,
                            child: InkWell(
                              key: ValueKey(_keys[index]),
                              onTap: actions[index],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _labels.length,
            (index) => Semantics(
              button: true,
              selected: index == _current,
              label:
                  'Imagen ${index + 1} de ${_labels.length}: ${_labels[index]}',
              child: InkWell(
                key: ValueKey('discover-dot-$index'),
                onTap: () => _goTo(index),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 14,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 6,
                    width: index == _current ? 22 : 6,
                    decoration: BoxDecoration(
                      color: index == _current
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
