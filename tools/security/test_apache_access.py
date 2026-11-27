"""Verifica .htaccess sobre Apache real. No imprime cuerpos de respuestas."""
import argparse
import urllib.error
import urllib.parse
import urllib.request


def status(url):
    try:
        response = urllib.request.urlopen(url, timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("base_url")
    base = parser.parse_args().base_url.rstrip("/")
    parsed = urllib.parse.urlsplit(base)
    if parsed.hostname not in ("localhost", "127.0.0.1", "::1") or parsed.username or parsed.password or parsed.query:
        raise RuntimeError("Esta prueba solo admite servidores locales sin credenciales en la URL")
    if status(base + "/health") != 200:
        raise RuntimeError("El health check público no respondió correctamente")
    paths = ["config/", "config/.jwt_secret", "config/.db_creds.php", "config/database.php",
             "src/helpers.php", "tests/money_test.php", "setup_db_user.php",
             "migrate_private_config.php", ".env", ".git/config", "config/database.php/extra"]
    for path in paths:
        if status(base + "/" + path) not in (403, 404):
            raise RuntimeError("Apache no bloqueó un recurso privado: " + path)
    print(f"Apache: health público y {len(paths)} recursos privados protegidos; cuerpos de respuesta omitidos.")


if __name__ == "__main__":
    main()
