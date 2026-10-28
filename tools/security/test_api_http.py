"""Prueba los límites HTTP sin usar cuentas, tokens ni credenciales reales."""

import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parents[2]


def token(payload, key):
    def encode(value):
        return base64.urlsafe_b64encode(json.dumps(value).encode()).rstrip(b"=")

    header = encode({"alg": "HS256", "typ": "JWT"})
    body = encode({**payload, "iat": int(time.time()), "exp": int(time.time()) + 300})
    data = header + b"." + body
    signature = base64.urlsafe_b64encode(hmac.new(key.encode(), data, hashlib.sha256).digest()).rstrip(b"=")
    return (data + b"." + signature).decode()


def request(base, path, *, bearer=None, body=None):
    headers = {"Content-Type": "application/json"}
    if bearer:
        headers["Authorization"] = "Bearer " + bearer
    req = urllib.request.Request(base + path, headers=headers,
                                 data=None if body is None else json.dumps(body).encode())
    try:
        response = urllib.request.urlopen(req, timeout=5)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status, response.headers, response.read()


def main():
    php = os.environ.get("PHP_BIN") or shutil.which("php")
    if not php and Path("C:/xampp/php/php.exe").is_file():
        php = "C:/xampp/php/php.exe"
    if not php:
        raise RuntimeError("PHP no está disponible")

    checks = 0

    def check(condition, label):
        nonlocal checks
        if not condition:
            raise RuntimeError("Falló la comprobación HTTP: " + label)
        checks += 1

    # El material de autenticación solo existe en la memoria de este proceso.
    key = secrets.token_hex(32)
    env = {**os.environ, "APP_ENV": "test", "JWT_SECRET": key,
           "DB_USER": "transita_security_no_database", "DB_PASS": secrets.token_hex(32)}
    passenger = token({"id": 7, "tipo": "civil"}, key)
    driver = token({"id": 7, "rol": "conductor"}, key)
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="transita-http-security-") as tmp:
        temporary = Path(tmp).resolve()
        if Path(tempfile.gettempdir()).resolve() not in temporary.parents:
            raise RuntimeError("Directorio temporal fuera del destino permitido")
        api = (ROOT / "api").as_posix().replace("'", "\\'")
        router = temporary / "router.php"
        router.write_text("<?php\n$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);\n"
                          "if (in_array($path, ['/setup_db_user.php', '/migrate_private_config.php'], true)) {\n"
                          f"require '{api}' . $path; return; }}\nrequire '{api}/index.php';\n", encoding="utf-8")
        with (temporary / "server.log").open("wb") as log:
            process = subprocess.Popen([php, "-S", f"127.0.0.1:{port}", "-t", str(ROOT / "api"), str(router)],
                                       env=env, stdout=log, stderr=log)
            try:
                for _ in range(100):
                    if process.poll() is not None:
                        raise RuntimeError("No se pudo iniciar el servidor de pruebas")
                    try:
                        status, headers, data = request(base, "/health")
                        break
                    except (OSError, urllib.error.URLError):
                        time.sleep(0.1)
                else:
                    raise RuntimeError("El servidor de pruebas no respondió")
                check(status == 200, "health disponible")
                check(headers.get("Cache-Control") == "no-store", "respuestas sin caché")
                check(headers.get("X-Content-Type-Options") == "nosniff", "tipo de contenido estricto")
                check(key.encode() not in data, "respuesta sin secreto")
                status, _, data = request(base, "/catalog/routes")
                catalog = json.loads(data)
                check(status == 200 and len(catalog["routes"]) == 29, "catálogo público disponible sin credenciales")
                prices = {route["id"]: route["fare_cents"] for route in catalog["routes"]}
                check(all(value is None for value in prices.values()), "ninguna tarifa pendiente habilita cobros")
                payment = {"user_id": 7, "conductor_id": 2, "puntos": 3.50,
                           "tipo_usuario": "civil", "metodo_pago": "qr", "payment_reference": "fixture-qr"}
                for bearer, body, expected in [
                    (None, payment, 401),
                    ("invalid", payment, 401),
                    (driver, payment, 403),
                    (passenger, {**payment, "user_id": 8}, 403),
                    (passenger, {**payment, "user_id": 0}, 403),
                    (passenger, {**payment, "metodo_pago": "nfc"}, 400),
                ]:
                    status, _, _ = request(base, "/transactions/pay", bearer=bearer, body=body)
                    check(status == expected, "pago sin autorización rechazado")
                for bearer in [passenger, driver]:
                    status, _, _ = request(base, "/transactions/recharge", bearer=bearer,
                                           body={"user_id": 7, "puntos": 100, "metodo_pago": "qr"})
                    check(status == 403, "recarga sin verificación rechazada")
                for path in ["/setup_db_user.php", "/migrate_private_config.php"]:
                    status, _, data = request(base, path)
                    check(status == 404 and not data, "script de mantenimiento exclusivo de CLI")
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    print(f"Seguridad HTTP: {checks} comprobaciones aprobadas; sin datos reales ni valores de credenciales.")


if __name__ == "__main__":
    main()
