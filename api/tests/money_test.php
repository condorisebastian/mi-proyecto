<?php
require __DIR__ . '/../src/helpers.php';
$checks = [[3.50, 350], ['0.50', 50], ['10.50', 1050], ['3,50', 350], [10, 1000], ['3.501', null], [-1, null], [true, null], [INF, null], ['abc', null]];
foreach ($checks as [$input, $expected]) {
    if (money_cents($input) !== $expected) throw new RuntimeException('Conversión de centavos incorrecta');
}
if (money_decimal(1050) !== '10.50' || money_decimal(50) !== '0.50') throw new RuntimeException('Importe SQL incorrecto');
if (money_cents('10.00') - money_cents('3.50') !== 650) throw new RuntimeException('Descuento incorrecto');
echo "Importes PHP: comprobaciones aprobadas.\n";
