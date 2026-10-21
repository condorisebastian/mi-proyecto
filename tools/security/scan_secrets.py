"""Ejecuta Gitleaks sin revelar coincidencias, secretos ni respuestas crudas."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def scan(repo, binary, history=False):
    repo = Path(repo).resolve()
    with tempfile.TemporaryDirectory(prefix="transita-secret-scan-") as tmp:
        temporary = Path(tmp).resolve()
        if Path(tempfile.gettempdir()).resolve() not in temporary.parents:
            raise RuntimeError("Directorio temporal fuera del destino permitido")
        report = temporary / "report.json"
        command = [str(binary), "git" if history else "dir", "--no-banner", "--redact=100",
                   "--config", str(ROOT / ".gitleaks.toml"), "--report-format=json",
                   "--report-path", str(report), "--exit-code=1"]
        if history:
            command += ["--log-opts=--all", str(repo)]
        else:
            # Evita leer secretos locales ignorados y también revisa archivos
            # nuevos todavía no añadidos a Git. No exporta el directorio .git.
            result = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                                    cwd=repo, capture_output=True, check=True)
            tree = temporary / "source"
            tree.mkdir()
            for filename in result.stdout.decode("utf-8").split("\0"):
                if not filename:
                    continue
                source = (repo / filename).resolve()
                target = (tree / filename).resolve()
                if repo not in source.parents or tree not in target.parents:
                    raise RuntimeError("Una ruta de Git está fuera del repositorio")
                if source.is_file():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
            command.append(str(tree))
        completed = subprocess.run(command, cwd=repo, capture_output=True)
        if completed.returncode not in (0, 1):
            raise RuntimeError("El escáner no pudo completar la revisión; su salida cruda se omitió")
        if not report.is_file():
            raise RuntimeError("El escáner no generó un informe verificable")
        findings = json.loads(report.read_text(encoding="utf-8"))
        if not isinstance(findings, list):
            raise RuntimeError("Formato de informe no válido")
        # Se reconstruye la salida a partir de una lista permitida de campos.
        # Nunca se imprime Secret, Match, líneas de código ni mensajes del motor.
        safe = [{"archivo": item.get("File", "").replace(str(temporary).replace('\\', '/') + '/source/', ''), "linea": item.get("StartLine"),
                 "regla": item.get("RuleID"), "commit": item.get("Commit", "")[:12]}
                for item in findings]
        if completed.returncode == 1 and not safe:
            raise RuntimeError("El escáner notificó un fallo sin informe verificable")
        return safe


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=ROOT)
    parser.add_argument("--history", action="store_true")
    parser.add_argument("--gitleaks", default=os.environ.get("GITLEAKS_BIN") or shutil.which("gitleaks"))
    args = parser.parse_args()
    if not args.gitleaks:
        raise RuntimeError("Configura GITLEAKS_BIN o instala Gitleaks 8.30.1")
    findings = scan(args.repo, args.gitleaks, args.history)
    if findings:
        print(json.dumps({"hallazgos": findings, "valores": "omitidos"}, ensure_ascii=False))
        return 1
    print("Escaneo de secretos aprobado (" + ("historial Git" if args.history else "archivos versionables") + "). Valores ocultos.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        print("No se completó el escaneo de secretos; revise la instalación y configuración del escáner.", file=sys.stderr)
        sys.exit(2)
