<?php
require __DIR__ . '/../src/helpers.php';
$checks = [[3.50, 350], ['0.50', 50], ['10.50', 1050], ['3,50', 350], [10, 1000], ['3.501', null], [-1, null], [true, null], [INF, null], ['abc', null]];
foreach ($checks as [$input, $expected]) {
    if (money_cents($input) !== $expected) throw new RuntimeException('Conversión de centavos incorrecta');
}
if (money_decimal(1050) !== '10.50' || money_decimal(50) !== '0.50') throw new RuntimeException('Importe SQL incorrecto');
if (money_cents('10.00') - money_cents('3.50') !== 650) throw new RuntimeException('Descuento incorrecto');
$payments = [
    ['civil', 'provincia_el_torno', 2550, 3, true],
    ['estudiante', 'provincia_la_guardia', 800, 1, true],
    ['civil', 'provincia_el_torno', 2551, 3, false],
    ['civil', 'provincia_samaipata', 2500, 1, false],
    ['civil', 'civil', 1050, 3, true],
    ['civil', 'civil', 750, 3, false],
    ['civil', 'estudiante', 300, 3, false],
    ['civil', null, 350, 1, true],
    ['civil', 'personalizado', 750, 3, true],
    ['estudiante', 'personalizado', 50, 1, true],
    ['civil', 'personalizado', 0, 1, false],
    ['civil', 'personalizado', -50, 1, false],
    ['civil', 'personalizado', 100000001, 1, false],
    ['civil', 'personalizado', 750, 0, false],
    ['civil', 'personalizado', 750, 51, false],
    ['desconocido', 'personalizado', 750, 1, false],
    ['civil', 'desconocido', 350, 1, false],
];
foreach ($payments as [$passenger, $qr, $cents, $quantity, $expected]) {
    if (trip_payment_matches($passenger, $qr, $cents, $quantity) !== $expected) {
        throw new RuntimeException('Validación de cobro incorrecta');
    }
}
echo "Importes PHP: comprobaciones aprobadas.\n";
