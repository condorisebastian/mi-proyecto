"""Regresión: una excepción para Firebase no debe ocultar claves privadas."""
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import unittest

from scan_secrets import scan


class SecretScanTest(unittest.TestCase):
    def setUp(self):
        self.binary = os.environ.get("GITLEAKS_BIN") or shutil.which("gitleaks")
        if not self.binary:
            self.fail("Gitleaks es obligatorio para esta prueba")
        self.tmp = tempfile.TemporaryDirectory(prefix="transita-scanner-test-")
        self.root = Path(self.tmp.name).resolve()
        if Path(tempfile.gettempdir()).resolve() not in self.root.parents:
            raise RuntimeError("Directorio temporal fuera del destino permitido")
        self.addCleanup(self.tmp.cleanup)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True, capture_output=True)

    def commit(self):
        subprocess.run(["git", "add", "."], cwd=self.root, check=True, capture_output=True)
        subprocess.run(["git", "-c", "user.name=Security Fixture", "-c", "user.email=fixture@example.invalid",
                        "-c", "commit.gpgsign=false", "-c", "core.hooksPath=" + str(self.root / "empty-hooks"),
                        "commit", "-qm", "test: fixture"], cwd=self.root, check=True, capture_output=True)

    def test_public_configuration_does_not_hide_private_material(self):
        config = self.root / "transita_bolivia/lib/firebase_options.dart"
        config.parent.mkdir(parents=True)
        public = "AIza" + secrets.token_urlsafe(40)[:35]
        config.write_text("apiKey: '" + public + "',\n", encoding="utf-8")
        self.assertEqual(scan(self.root, self.binary), [])
        begin = '-----BEGIN ' + 'PRIVATE KEY-----'
        end = '-----END ' + 'PRIVATE KEY-----'
        config.write_text(config.read_text(encoding="utf-8") + '\n' + begin + '\n'
                          + secrets.token_urlsafe(60) + '\n' + end + '\n', encoding="utf-8")
        findings = scan(self.root, self.binary)
        self.assertTrue(findings)
        self.assertNotIn(public, str(findings))
        self.assertTrue(any(item["regla"] == "private-key" for item in findings))

    def test_ignored_files_are_excluded_but_history_is_checked(self):
        (self.root / ".gitignore").write_text(".env\n", encoding="utf-8")
        material = "jwt_secret = '" + secrets.token_hex(32) + "'\n"
        (self.root / ".env").write_text(material, encoding="utf-8")
        self.assertEqual(scan(self.root, self.binary), [])
        fixture = self.root / "example.php"
        fixture.write_text(material, encoding="utf-8")
        self.assertTrue(scan(self.root, self.binary))
        self.commit()
        fixture.unlink()
        self.commit()
        self.assertEqual(scan(self.root, self.binary), [])
        findings = scan(self.root, self.binary, history=True)
        self.assertTrue(findings)
        self.assertNotIn(material.strip(), str(findings))


if __name__ == "__main__":
    unittest.main()
