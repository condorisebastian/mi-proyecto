import 'package:flutter/material.dart';
import '../data/province_routes.dart';
import '../models/money.dart';
import '../models/trip_qr.dart';
import '../widgets/charge_qr_dialog.dart';
import 'driver/pos_screen.dart';
import '../services/app_preferences.dart';
import 'accessibility_screen.dart';

class ProvinceRoutesScreen extends StatefulWidget {
  const ProvinceRoutesScreen({super.key, this.conductorId, this.preferences});
  final int? conductorId;
  final AppPreferences? preferences;
  @override
  State<ProvinceRoutesScreen> createState() => _ProvinceRoutesScreenState();
}

class _ProvinceRoutesScreenState extends State<ProvinceRoutesScreen> {
  String _query = '';
  int _quantity = 1;
  bool _onlyFavorites = false;
  final Set<String> _savingFavorites = {};
  late final _preferences = widget.preferences ?? AppPreferences.instance;
  @override
  void initState() {
    super.initState();
    _preferences.load();
  }

  Future<void> _toggleFavorite(String id) async {
    setState(() => _savingFavorites.add(id));
    try {
      await _preferences.toggleFavorite(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar el favorito. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFavorites.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final routes = provinceRoutes
        .where((r) => !_onlyFavorites || _preferences.isFavorite(r.id))
        .where(
          (r) => '${r.destination} ${r.province}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    final order = {
      for (var i = 0; i < provinceRoutes.length; i++) provinceRoutes[i].id: i,
    };
    routes.sort((a, b) {
      final favoriteOrder =
          (_preferences.isFavorite(b.id) ? 1 : 0) -
          (_preferences.isFavorite(a.id) ? 1 : 0);
      return favoriteOrder != 0
          ? favoriteOrder
          : order[a.id]!.compareTo(order[b.id]!);
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provincias'),
        actions: const [AccessibilityButton()],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 860,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Desde Santa Cruz de la Sierra',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tarifa por verificar. Los cobros provinciales se habilitarán '
                'al confirmar el importe, el servicio y la vigencia.',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar destino o provincia',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: !_onlyFavorites,
                    onSelected: (_) => setState(() => _onlyFavorites = false),
                  ),
                  ChoiceChip(
                    label: Text('Favoritos (${_preferences.favorites.length})'),
                    selected: _onlyFavorites,
                    onSelected: (_) => setState(() => _onlyFavorites = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (provinceRoutes.any((route) => route.canCharge))
                Row(
                  children: [
                    const Expanded(child: Text('Cantidad de pasajes')),
                    IconButton(
                      tooltip: 'Quitar un pasaje',
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_quantity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      tooltip: 'Añadir un pasaje',
                      onPressed: _quantity < TripQr.maxPassengers
                          ? () => setState(() => _quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (routes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _onlyFavorites && _preferences.favorites.isEmpty
                        ? 'Todavía no tienes favoritos. Toca la estrella de un destino para guardarlo.'
                        : 'No hay destinos con esa búsqueda.',
                  ),
                ),
              for (final route in routes)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                route.destination,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              key: ValueKey('favorite-${route.id}'),
                              tooltip:
                                  '${_preferences.isFavorite(route.id) ? 'Quitar de favoritos' : 'Guardar favorito'}: ${route.destination}',
                              isSelected: _preferences.isFavorite(route.id),
                              icon: const Icon(Icons.star_border),
                              selectedIcon: const Icon(Icons.star),
                              onPressed: _savingFavorites.contains(route.id)
                                  ? null
                                  : () => _toggleFavorite(route.id),
                            ),
                          ],
                        ),
                        Text(route.province),
                        const SizedBox(height: 8),
                        Text(
                          route.canCharge
                              ? 'Bs ${Money.format(route.fareCents! / 100)} / persona · Total Bs ${Money.format(route.fareCents! * _quantity / 100)}'
                              : 'Tarifa por verificar',
                        ),
                        if (widget.conductorId != null && route.canCharge)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  icon: const Icon(Icons.qr_code),
                                  label: const Text('MOSTRAR QR'),
                                  onPressed: () => showTripQr(
                                    context,
                                    TripQr(
                                      conductorId: widget.conductorId!,
                                      tipo: route.qrType,
                                      puntos:
                                          route.fareCents! * _quantity / 100,
                                      reference: TripQr.newReference(),
                                      cantidad: _quantity,
                                    ),
                                    route.destination,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.contactless),
                                  label: const Text('COBRAR CON TARJETA'),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => PosScreen(
                                        routeId: route.id,
                                        amountCents:
                                            route.fareCents! * _quantity,
                                        quantity: _quantity,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
