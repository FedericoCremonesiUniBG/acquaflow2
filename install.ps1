param(
    [Parameter(Mandatory=$true)]
    [string]$TomcatPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TomcatPath)) {
    Write-Host "Percorso Tomcat non valido: $TomcatPath"
    exit 1
}

$radiceProgetto = $PSScriptRoot

Write-Host "Arresto di eventuali istanze precedenti..."

$connessioneDjango = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
if ($connessioneDjango) {
    Stop-Process -Id $connessioneDjango.OwningProcess -Force -ErrorAction SilentlyContinue
    Write-Host "Istanza precedente di Django arrestata."
}

if (Test-Path "$TomcatPath\bin\shutdown.bat") {
    Push-Location "$TomcatPath\bin"
    try { .\shutdown.bat 2>$null | Out-Null } catch {}
    Pop-Location
    Start-Sleep -Seconds 3
}

Write-Host "=== Passo 1/7: Creazione utente e database PostgreSQL ==="
$dbPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 20 | ForEach-Object { [char]$_ })

$env:PGPASSWORD = Read-Host "Inserisci la password dell'utente postgres"
psql -U postgres -c "DROP DATABASE IF EXISTS acquaflow_locale;"
psql -U postgres -c "DROP USER IF EXISTS acquaflow_app;"
psql -U postgres -c "CREATE USER acquaflow_app WITH PASSWORD '$dbPassword';"
psql -U postgres -c "CREATE DATABASE acquaflow_locale OWNER acquaflow_app;"
psql -U postgres -d acquaflow_locale -c "GRANT ALL ON SCHEMA public TO acquaflow_app;"
Remove-Item Env:\PGPASSWORD

$env:PGPASSWORD = $dbPassword
psql -U acquaflow_app -d acquaflow_locale -f "$radiceProgetto\db\schema_postgres.sql"
Remove-Item Env:\PGPASSWORD

Write-Host "=== Passo 2/7: Configurazione credenziali ==="
@"
DB_NAME=acquaflow_locale
DB_USER=acquaflow_app
DB_PASSWORD=$dbPassword
DB_HOST=localhost
DB_PORT=5432
"@ | Out-File -FilePath "$radiceProgetto\django\.env" -Encoding ascii

Write-Host "=== Passo 3/7: Preparazione ambiente Python ==="
Push-Location "$radiceProgetto\django"
if (-not (Test-Path ".\venv")) {
    python -m venv venv
}
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt --quiet
python manage.py migrate
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore durante l'applicazione delle migrazioni Django. Installazione interrotta."
    exit 1
}

Write-Host "=== Passo 4/7: Avvio del web-service Django ==="
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$radiceProgetto\django'; .\venv\Scripts\Activate.ps1; python manage.py runserver"
Start-Sleep -Seconds 5
Pop-Location

Write-Host "=== Passo 5/7: Compilazione della Servlet ==="
Push-Location "$radiceProgetto\servlet"
.\mvnw.cmd clean package
if ($LASTEXITCODE -ne 0) {
    Write-Host "Errore durante la compilazione della Servlet. Installazione interrotta."
    exit 1
}
Pop-Location

Write-Host "=== Passo 6/7: Distribuzione su Tomcat ==="
Copy-Item "$radiceProgetto\servlet\target\migrazione.war" -Destination "$TomcatPath\webapps\migrazione.war" -Force
Remove-Item "$TomcatPath\webapps\migrazione" -Recurse -Force -ErrorAction SilentlyContinue
Push-Location "$TomcatPath\bin"
.\startup.bat
Pop-Location

Write-Host "In attesa che Tomcat sia pronto..."
$tomcatPronto = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -TimeoutSec 2 | Out-Null
        $tomcatPronto = $true
        break
    } catch {
        Start-Sleep -Seconds 2
    }
}

if (-not $tomcatPronto) {
    Write-Host "Tomcat non risulta ancora pronto dopo 60 secondi."
    Write-Host "Attendere qualche secondo, poi visitare manualmente: http://localhost:8080/migrazione/migra"
    exit 1
}

Write-Host "=== Passo 7/7: Avvio della migrazione ==="
Invoke-RestMethod -Uri "http://localhost:8080/migrazione/migra"

Write-Host ""
Write-Host "Installazione completata."
