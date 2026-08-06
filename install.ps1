param(
    [Parameter(Mandatory=$true)]
    [string]$TomcatPath
)

# RIMOSSO: $ErrorActionPreference = "Stop" 
# Gestiamo le uscite forzate manualmente per evitare falsi positivi con i programmi nativi.

# Richiamo dello script esterno tramite Dot-Sourcing
. "$PSScriptRoot\setup_env.ps1"

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Magenta
Write-Host "      INSTALLAZIONE E MIGRAZIONE AMBIENTE LOCALE" -ForegroundColor Magenta
Write-Host "=======================================================" -ForegroundColor Magenta
Write-Host "Automazione configurazione DB, Server Web e Servlet." -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $TomcatPath)) {
    Write-Host "[ ERRORE ] Percorso Tomcat non valido: $TomcatPath" -ForegroundColor Red
    exit 1
}

$radiceProgetto = $PSScriptRoot

# --- FUNZIONI HELPER PER LA GRAFICA ---
function Write-TitoloStep([string]$Titolo) {
    Write-Host "$Titolo" -ForegroundColor Cyan
}

function Write-Esito([string]$Nome, [bool]$Successo, [string]$Dettaglio, [bool]$Fatale = $false) {
    $padNome = $Nome.PadRight(18)
    if ($Successo) {
        Write-Host "  [ OK ] " -ForegroundColor Green -NoNewline
        Write-Host "$padNome " -NoNewline -ForegroundColor White
        Write-Host "- $Dettaglio" -ForegroundColor Gray
    } else {
        Write-Host "  [ ERRORE ] " -ForegroundColor Red -NoNewline
        Write-Host "$padNome " -NoNewline -ForegroundColor White
        Write-Host "- $Dettaglio" -ForegroundColor Red
        
        if ($Fatale) {
            Write-Host "`nInstallazione interrotta." -ForegroundColor Red
            exit 1
        }
    }
}
# --------------------------------------

Write-TitoloStep "Pulizia ambiente precedente"
$connessioneDjango = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
if ($connessioneDjango) {
    Stop-Process -Id $connessioneDjango.OwningProcess -Force -ErrorAction SilentlyContinue
}
if (Test-Path "$TomcatPath\bin\shutdown.bat") {
    Push-Location "$TomcatPath\bin"
    try { & .\shutdown.bat 2>&1 | Out-Null } catch {}
    Pop-Location
    Start-Sleep -Seconds 3
}
Write-Esito -Nome "Pulizia" -Successo $true -Dettaglio "Eventuali processi precedenti interrotti."
Write-Host ""


Write-TitoloStep "Passo 1/7: Creazione Database PostgreSQL"
$dbPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 20 | ForEach-Object { [char]$_ })

Write-Host "  Richiesta privilegi di amministratore per il DB." -ForegroundColor Yellow

$connessioneRiuscita = $false

# Ciclo finché la password non è corretta (o l'utente non decide di uscire)
while (-not $connessioneRiuscita) {
    $env:PGPASSWORD = Read-Host "  Inserisci la password dell'utente 'postgres' (o lascia vuoto per uscire)"
    
    # Via di fuga nel caso in cui l'utente voglia abortire
    if ([string]::IsNullOrWhiteSpace($env:PGPASSWORD)) {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
        Write-Esito -Nome "PostgreSQL" -Successo $false -Dettaglio "Operazione annullata dall'utente." -Fatale $true
    }

    # Testiamo la connessione con una query innocua ("SELECT 1;")
    psql -q -U postgres -c "SELECT 1;" 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        $connessioneRiuscita = $true
        Write-Host "  Password accettata. Configurazione in corso..." -ForegroundColor DarkGray
    } else {
        Write-Host "  [!] Password errata o servizio PostgreSQL non attivo. Riprova." -ForegroundColor Red
    }
}

try {
    # Ora che siamo sicuri che le credenziali sono giuste, eseguiamo le operazioni distruttive
    psql -q -U postgres -c "DROP DATABASE IF EXISTS acquaflow_locale;" 2>&1 | Out-Null
    psql -q -U postgres -c "DROP USER IF EXISTS acquaflow_app;" 2>&1 | Out-Null
    psql -q -U postgres -c "CREATE USER acquaflow_app WITH PASSWORD '$dbPassword';" 2>&1 | Out-Null
    psql -q -U postgres -c "CREATE DATABASE acquaflow_locale OWNER acquaflow_app;" 2>&1 | Out-Null
    psql -q -U postgres -d acquaflow_locale -c "GRANT ALL ON SCHEMA public TO acquaflow_app;" 2>&1 | Out-Null
    psql -q -U postgres -d acquaflow_locale -c "ALTER SCHEMA public OWNER TO acquaflow_app;" 2>&1 | Out-Null

    # Cambiamo identità: passiamo al nuovo utente app appena creato per importare lo schema
    $env:PGPASSWORD = $dbPassword
    psql -q -U acquaflow_app -d acquaflow_locale -f "$radiceProgetto\db\schema_postgres.sql" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Errore durante l'importazione dello schema SQL." }
    
    Write-Esito -Nome "PostgreSQL" -Successo $true -Dettaglio "Utente 'acquaflow_app' e struttura DB creati."
} catch {
    Write-Esito -Nome "PostgreSQL" -Successo $false -Dettaglio $_.Exception.Message -Fatale $true
} finally {
    # Puliamo SEMPRE la password dall'ambiente alla fine, sia in caso di successo che di errore
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
Write-Host ""

Write-TitoloStep "Passo 2/7: Configurazione credenziali"
@"
DB_NAME=acquaflow_locale
DB_USER=acquaflow_app
DB_PASSWORD=$dbPassword
DB_HOST=localhost
DB_PORT=5432
"@ | Out-File -FilePath "$radiceProgetto\django\.env" -Encoding ascii
Write-Esito -Nome "File .env" -Successo $true -Dettaglio "Credenziali generate e salvate per Django."
Write-Host ""


Write-TitoloStep "Passo 3/7: Preparazione ambiente Python"
Push-Location "$radiceProgetto\django"
Write-Host "  Attendere: configurazione venv e dipendenze in corso..." -ForegroundColor DarkGray
try {
    if (-not (Test-Path ".\venv")) {
        if (Get-Command py -ErrorAction SilentlyContinue) {
            py -m venv venv 2>&1 | Out-Null
        } else {
            python -m venv venv 2>&1 | Out-Null
        }
    }
    .\venv\Scripts\Activate.ps1
    pip install -r requirements.txt --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Errore durante l'installazione delle dipendenze (pip)." }
    
    $migrateOutput = python manage.py migrate 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Errore migrazioni: $migrateOutput" }
    
    Write-Esito -Nome "Django Setup" -Successo $true -Dettaglio "Ambiente virtuale pronto e migrazioni applicate."
} catch {
    Write-Esito -Nome "Django Setup" -Successo $false -Dettaglio $_.Exception.Message -Fatale $true
}
Pop-Location
Write-Host ""


Write-TitoloStep "Passo 4/7: Avvio del web-service Django"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$radiceProgetto\django'; .\venv\Scripts\Activate.ps1; python manage.py runserver"
Start-Sleep -Seconds 3
Write-Esito -Nome "Server Web" -Successo $true -Dettaglio "Finestra Django aperta. NON CHIUDERLA."
Write-Host ""


Write-TitoloStep "Passo 5/7: Compilazione della Servlet (Maven)"
Push-Location "$radiceProgetto\servlet"
Write-Host "  Attendere: compilazione del pacchetto .war in corso..." -ForegroundColor DarkGray
try {
    & .\mvnw.cmd clean package 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Errore durante la compilazione Maven." }
    Write-Esito -Nome "Maven Build" -Successo $true -Dettaglio "Servlet compilata con successo (migrazione.war)."
} catch {
    Write-Esito -Nome "Maven Build" -Successo $false -Dettaglio $_.Exception.Message -Fatale $true
}
Pop-Location
Write-Host ""


Write-TitoloStep "Passo 6/7: Distribuzione su Tomcat"
Copy-Item "$radiceProgetto\servlet\target\migrazione.war" -Destination "$TomcatPath\webapps\migrazione.war" -Force
Remove-Item "$TomcatPath\webapps\migrazione" -Recurse -Force -ErrorAction SilentlyContinue

Push-Location "$TomcatPath\bin"
Start-Process "cmd.exe" -ArgumentList "/c startup.bat"
Pop-Location

Write-Host "  Attendere: avvio di Tomcat in corso..." -ForegroundColor DarkGray
$tomcatPronto = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        # Aggiunto -ErrorAction Stop per far funzionare correttamente il catch in caso di server offline
        Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop | Out-Null
        $tomcatPronto = $true
        break
    } catch {
        Start-Sleep -Seconds 2
    }
}

if ($tomcatPronto) {
    Write-Esito -Nome "Tomcat Server" -Successo $true -Dettaglio "Finestra Tomcat aperta e server in ascolto."
} else {
    Write-Esito -Nome "Tomcat Server" -Successo $false -Dettaglio "Tomcat non risponde. Procedere manualmente." -Fatale $true
}
Write-Host ""


Write-TitoloStep "Passo 7/7: Esecuzione della Migrazione Dati"
Write-Host "  Il processo puo' richiedere un minuto. Non chiudere nessuna finestra." -ForegroundColor DarkGray

$jobMigrazione = Start-Job -ScriptBlock {
    # Aggiunto -ErrorAction Stop in modo che se la chiamata fallisce, il Job vada in stato 'Failed'
    Invoke-RestMethod -Uri "http://localhost:8080/migrazione/migra" -ErrorAction Stop
}

$simboli = @('|', '/', '-', '\')
$i = 0
while ($jobMigrazione.State -eq 'Running') {
    Write-Host -NoNewline "`r  $($simboli[$i % 4]) Connessione API e trasferimento dati in corso..." -ForegroundColor Cyan
    $i++
    Start-Sleep -Milliseconds 200
}
# Pulisce la riga dell'animazione
Write-Host -NoNewline "`r                                                               `r"

# Riceviamo l'output e catturiamo gli errori in una variabile separata in modo invisibile
$risultatoMigrazione = Receive-Job -Job $jobMigrazione -ErrorVariable erroriJob -ErrorAction SilentlyContinue
$statoJob = $jobMigrazione.State
Remove-Job -Job $jobMigrazione

# Controllo intelligente dell'esito
if ($statoJob -eq 'Completed' -and -not $erroriJob) {
    # Se per caso l'output testuale è vuoto, mettiamo un testo di default
    $testoDettaglio = if ($risultatoMigrazione) { ($risultatoMigrazione -join " " -replace "`n", " ") } else { "Completata." }
    Write-Esito -Nome "Migrazione" -Successo $true -Dettaglio $testoDettaglio
} else {
    # Estraiamo solo il messaggio d'errore pulito invece dell'intero blocco rosso di PowerShell
    $messaggioErrore = if ($erroriJob) { $erroriJob[0].Exception.Message } else { "Connessione interrotta o fallita." }
    Write-Esito -Nome "Migrazione" -Successo $false -Dettaglio $messaggioErrore
}
Write-Host ""


Write-TitoloStep "Verifica automatica dell'integrita' dati (Remoto vs Locale)"
$conteggiRemoti = Invoke-RestMethod -Uri "http://distribuzioneacqua2.altervista.org/php/export/conteggio.php"

$mappaTabelle = [ordered]@{
    "clienti" = "cliente"
    "punti_fornitura" = "puntofornitura"
    "utenze" = "utenza"
    "fatture" = "fattura"
    "letture" = "lettura"
}

$env:PGPASSWORD = $dbPassword
$tuttoOk = $true
foreach ($chiave in $mappaTabelle.Keys) {
    $tabellaLocale = $mappaTabelle[$chiave]
    $conteggioRemoto = $conteggiRemoti.$chiave
    
    $risultatoPsql = psql -q -U acquaflow_app -d acquaflow_locale -t -c "SELECT COUNT(*) FROM $tabellaLocale;" 2>&1
    $conteggioLocale = ($risultatoPsql -join "").Trim()

    if ("$conteggioRemoto" -eq "$conteggioLocale") {
        Write-Esito -Nome $tabellaLocale -Successo $true -Dettaglio "Locale: $conteggioLocale | Remoto: $conteggioRemoto"
    } else {
        Write-Esito -Nome $tabellaLocale -Successo $false -Dettaglio "Locale: $conteggioLocale | Remoto: $conteggioRemoto (DISCORDANTI)"
        $tuttoOk = $false
    }
}
Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue

Write-Host ""
if ($tuttoOk) {
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host " INSTALLAZIONE E MIGRAZIONE COMPLETATE CON SUCCESSO! " -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
} else {
    Write-Host "=======================================================" -ForegroundColor Red
    Write-Host " MIGRAZIONE COMPLETATA CON ERRORI NEI DATI! " -ForegroundColor Red
    Write-Host " Controllare i log per verificare i conteggi mancanti." -ForegroundColor Red
    Write-Host "=======================================================" -ForegroundColor Red
}
Write-Host ""