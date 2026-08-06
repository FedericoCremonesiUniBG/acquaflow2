param(
    [string]$TomcatPath
)

# Richiamo dello script esterno tramite Dot-Sourcing
. "$PSScriptRoot\setup_env.ps1"

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "       CONTROLLO DEI PREREQUISITI DI SISTEMA" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Questo script puo' essere eseguito da qualsiasi cartella." -ForegroundColor Gray
Write-Host ""

# Funzione helper per stampare i risultati in modo pulito e allineato
function Write-Risultato {
    param([string]$Nome, [bool]$Trovato, [string]$Dettaglio, [string]$Richiesta)
    
    $padNome = $Nome.PadRight(15)
    if ($Trovato) {
        Write-Host "[ OK ] " -ForegroundColor Green -NoNewline
        Write-Host "$padNome " -NoNewline -ForegroundColor White
        Write-Host "- $Dettaglio" -ForegroundColor Gray
    } else {
        Write-Host "[ MANCANTE ] " -ForegroundColor Red -NoNewline
        Write-Host "$padNome " -NoNewline -ForegroundColor White
        Write-Host "- $Richiesta" -ForegroundColor Red
    }
}

# --- Controllo Python ---
$pythonTrovato = $false
$pythonVer = ""
if ((Get-Command python -ErrorAction SilentlyContinue) -and (Get-Command python).Source -notlike "*WindowsApps*") {
    $pythonVer = (python --version 2>&1) -join ""
    $pythonTrovato = $true
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $pythonVer = (py --version 2>&1) -join ""
    $pythonTrovato = $true
}
Write-Risultato -Nome "Python" -Trovato $pythonTrovato -Dettaglio $pythonVer -Richiesta "Scaricare Python 3.12 o successiva."

# --- Controllo Java ---
$javaTrovato = $false
$javaVer = ""
if (Get-Command java -ErrorAction SilentlyContinue) {
    # Cattura l'output di Java (che scrive su ErrorStream) e prende solo la prima riga
    $javaOut = cmd /c "java -version 2>&1"
    if ($javaOut.Count -gt 0) { $javaVer = $javaOut[0] }
    $javaTrovato = $true
}
Write-Risultato -Nome "Java" -Trovato $javaTrovato -Dettaglio $javaVer -Richiesta "Scaricare JDK 17 o successiva."

# --- Controllo PostgreSQL ---
$psqlTrovato = $false
$psqlVer = ""
if (Get-Command psql -ErrorAction SilentlyContinue) {
    $psqlVer = (psql --version 2>&1) -join ""
    $psqlTrovato = $true
}
Write-Risultato -Nome "PostgreSQL" -Trovato $psqlTrovato -Dettaglio $psqlVer -Richiesta "Scaricare una versione recente di PostgreSQL."

# --- Controllo Git ---
$gitTrovato = $false
$gitVer = ""
if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitVer = (git --version 2>&1) -join ""
    $gitTrovato = $true
}
Write-Risultato -Nome "Git" -Trovato $gitTrovato -Dettaglio $gitVer -Richiesta "Scaricare Git per Windows."

# --- Controllo Apache Tomcat ---
$trovatoTomcat = $false
$tomcatVer = ""

# 1. Tenta tramite la variabile d'ambiente CATALINA_HOME
if ($env:CATALINA_HOME -and (Test-Path "$env:CATALINA_HOME\bin\catalina.bat")) {
    $TomcatPath = $env:CATALINA_HOME
    $trovatoTomcat = $true
}
# 2. Tenta tramite il parametro passato manualmente
elseif ($TomcatPath -and (Test-Path "$TomcatPath\bin\catalina.bat")) {
    $trovatoTomcat = $true
}
# 3. Tenta cercando nei percorsi di installazione più comuni
else {
    $percorsiComuni = @(
        "C:\Program Files\Apache Software Foundation\Tomcat 11.0",
        "C:\Program Files\Apache Software Foundation\Tomcat 10.1",
        "C:\Tomcat",
        "C:\Tomcat11"
    )
    foreach ($percorso in $percorsiComuni) {
        if (Test-Path "$percorso\bin\catalina.bat") {
            $TomcatPath = $percorso
            $trovatoTomcat = $true
            break
        }
    }
}

if ($trovatoTomcat) {
    $catalinaJar = "$TomcatPath\lib\catalina.jar"
    
    if (Test-Path $catalinaJar) {
        # Trucco Infallibile: Interroga direttamente il file .jar di Tomcat usando Java
        $tomcatOutput = cmd /c "java -cp `"$catalinaJar`" org.apache.catalina.util.ServerInfo 2>&1"
        
        # Estrai la riga con la versione
        $rigaVersione = $tomcatOutput | Where-Object { $_ -match "Server version:" } | Select-Object -First 1
        
        if ($rigaVersione) {
            $versionePulita = $rigaVersione -replace "Server version:\s*", ""
            $tomcatVer = "$versionePulita (Path: $TomcatPath)"
        } else {
            $tomcatVer = "Trovato (Path: $TomcatPath) ma lettura versione fallita"
        }
    } else {
        $tomcatVer = "Trovato (Path: $TomcatPath) ma catalina.jar mancante"
    }
}

Write-Risultato -Nome "Apache Tomcat" -Trovato $trovatoTomcat -Dettaglio $tomcatVer -Richiesta "Non trovato. Usa: .\controlla_prerequisiti.ps1 -TomcatPath <percorso>"

Write-Host ""
Write-Host "Controllo terminato." -ForegroundColor Cyan
Write-Host ""