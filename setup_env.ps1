Write-Host ""
Write-Host "=======================================================" -ForegroundColor Blue
Write-Host "         CONFIGURAZIONE AMBIENTE DI LAVORO" -ForegroundColor Blue
Write-Host "=======================================================" -ForegroundColor Blue
Write-Host "Rilevamento e configurazione dinamica dei percorsi (PATH)." -ForegroundColor Gray
Write-Host ""

# Funzione helper per l'output coerente
function Write-RisultatoConfig {
    param(
        [string]$Nome, 
        [bool]$Successo, 
        [string]$Dettaglio, 
        [bool]$Fatale = $false
    )
    
    $padNome = $Nome.PadRight(15)
    if ($Successo) {
        Write-Host "[ OK ] " -ForegroundColor Green -NoNewline
        Write-Host "$padNome " -NoNewline -ForegroundColor White
        Write-Host "- $Dettaglio" -ForegroundColor Gray
    } else {
        Write-Host "[ ERRORE ] " -ForegroundColor Red -NoNewline
        Write-Host "$padNome " -NoNewline -ForegroundColor White
        Write-Host "- $Dettaglio" -ForegroundColor Red
        
        if ($Fatale) {
            Write-Host ""
            Write-Host "=> Esecuzione interrotta. Risolvere il problema per continuare." -ForegroundColor Red
            Write-Host ""
            exit 1
        }
    }
}

# --- 1. RILEVAMENTO DINAMICO JAVA (JDK) ---
$javaTrovato = $false
$javaDettaglio = ""

if (-not $env:JAVA_HOME) {
    $javaRegPath = "HKLM:\SOFTWARE\JavaSoft\JDK"
    if (Test-Path $javaRegPath) {
        $latestVersion = (Get-ChildItem -Path $javaRegPath | Sort-Object PSChildName -Descending | Select-Object -First 1).PSChildName
        $env:JAVA_HOME = (Get-ItemProperty -Path "$javaRegPath\$latestVersion").JavaHome
    } else {
        # Fallback: cerca in percorsi standard
        $possibleJava = Get-ChildItem "C:\Program Files\Java\jdk*", "C:\Program Files\Eclipse Adoptium\jdk*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($possibleJava) { $env:JAVA_HOME = $possibleJava.FullName }
    }
}

if ($env:JAVA_HOME) {
    # Evita di duplicare la path se lo script viene eseguito più volte
    if ($env:Path -notlike "*$env:JAVA_HOME\bin*") {
        $env:Path = "$env:JAVA_HOME\bin;" + $env:Path
    }
    $javaTrovato = $true
    $javaDettaglio = "JAVA_HOME configurato: $env:JAVA_HOME"
} else {
    $javaDettaglio = "JDK non trovato. Installare Java o impostare la variabile JAVA_HOME."
}

Write-RisultatoConfig -Nome "Java (JDK)" -Successo $javaTrovato -Dettaglio $javaDettaglio -Fatale $true


# --- 2. RILEVAMENTO DINAMICO POSTGRESQL ---
$pgTrovato = $false
$pgDettaglio = ""

if (Get-Command psql -ErrorAction SilentlyContinue) {
    $pgTrovato = $true
    $pgDettaglio = "Gia' presente nel PATH di sistema"
} else {
    # Cerca la cartella di installazione di PostgreSQL
    $pgBaseDir = "C:\Program Files\PostgreSQL"
    if (Test-Path $pgBaseDir) {
        $latestPg = Get-ChildItem $pgBaseDir -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latestPg -and (Test-Path "$($latestPg.FullName)\bin\psql.exe")) {
            $env:Path = "$($latestPg.FullName)\bin;" + $env:Path
            $pgTrovato = $true
            $pgDettaglio = "Aggiunto al PATH: $($latestPg.FullName)\bin"
        }
    }
}

if (-not $pgTrovato) {
    $pgDettaglio = "Comando 'psql' non trovato. Assicurarsi che PostgreSQL sia installato."
}

Write-RisultatoConfig -Nome "PostgreSQL" -Successo $pgTrovato -Dettaglio $pgDettaglio -Fatale $true


# --- 3. RILEVAMENTO DINAMICO PYTHON ---
$pyTrovato = $false
$pyDettaglio = ""

if ((Get-Command python -ErrorAction SilentlyContinue) -and (Get-Command python).Source -notlike "*WindowsApps*") {
    $pyTrovato = $true
    $pyDettaglio = "Gia' presente nel PATH di sistema"
} else {
    # Cerca la cartella di installazione standard di Python in AppData
    $pythonBase = "$env:LOCALAPPDATA\Programs\Python"
    if (Test-Path $pythonBase) {
        $latestPython = Get-ChildItem $pythonBase -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latestPython) {
            # Aggiunge al PATH sia la root di Python che la cartella Scripts (per pip)
            $env:Path = "$($latestPython.FullName);$($latestPython.FullName)\Scripts;" + $env:Path
            $pyTrovato = $true
            $pyDettaglio = "Aggiunto al PATH: $($latestPython.FullName)"
        }
    }
}

if (-not $pyTrovato) {
    # Non lo segno come fatale perché lo script dei prerequisiti farà un controllo più approfondito anche su 'py'
    $pyDettaglio = "Non configurato nel PATH automaticamente. Il controllo prerequisiti verifichera' ulteriormente."
}

Write-RisultatoConfig -Nome "Python" -Successo $pyTrovato -Dettaglio $pyDettaglio -Fatale $false

Write-Host ""