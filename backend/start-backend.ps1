$ErrorActionPreference = 'Stop'

$backendDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = "$env:USERPROFILE\.local\share\opencode"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

$outLog = Join-Path $logDir 'backend_out.log'
$errLog = Join-Path $logDir 'backend_err.log'

$alreadyRunning = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if ($alreadyRunning) {
    Write-Output "El backend ya esta corriendo en el puerto 3000 (PID $($alreadyRunning.OwningProcess))."
    exit 0
}

Start-Process -FilePath "node" -ArgumentList "server.js" `
    -WorkingDirectory $backendDir `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -WindowStyle Hidden

Start-Sleep -Seconds 3

$check = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if ($check) {
    Write-Output "Backend iniciado correctamente en el puerto 3000 (PID $($check.OwningProcess))."
} else {
    Write-Output "Fallo al iniciar el backend. Revisa: $errLog"
    exit 1
}
