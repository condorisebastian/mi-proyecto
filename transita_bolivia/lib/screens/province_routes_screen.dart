import 'package:flutter/material.dart';
import '../data/province_routes.dart';
import '../models/money.dart';
import '../models/trip_qr.dart';
import '../widgets/charge_qr_dialog.dart';
import 'driver/pos_screen.dart';

class ProvinceRoutesScreen extends StatefulWidget {
  const ProvinceRoutesScreen({super.key, this.conductorId});
  final int? conductorId;
  @override
  State<ProvinceRoutesScreen> createState() => _ProvinceRoutesScreenState();
}

class _ProvinceRoutesScreenState extends State<ProvinceRoutesScreen> {
  String _query = '';
  int _quantity = 1;
  @override
  Widget build(BuildContext context) {
    final routes = provinceRoutes
        .where(
          (r) => '${r.destination} ${r.province}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Provincias')),
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
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay destinos con esa búsqueda.'),
                ),
              for (final route in routes)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.destination,
                          style: Theme.of(context).textTheme.titleLarge,
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
