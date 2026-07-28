# Rilevamento automatico di JAVA_HOME tramite il Registro di Sistema
if (-not $env:JAVA_HOME) {
    $javaRegPath = "HKLM:\SOFTWARE\JavaSoft\JDK"
    if (Test-Path $javaRegPath) {
        $latestVersion = (Get-ChildItem -Path $javaRegPath | Sort-Object PSChildName -Descending | Select-Object -First 1).PSChildName
        $env:JAVA_HOME = (Get-ItemProperty -Path "$javaRegPath\$latestVersion").JavaHome
    } else {
        # Fallback: cerca in percorsi standard
        $possibleJava = Get-ChildItem "C:\Program Files\Java\jdk*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($possibleJava) { $env:JAVA_HOME = $possibleJava.FullName }
    }
}

if ($env:JAVA_HOME) {
    $env:Path = "$env:JAVA_HOME\bin;" + $env:Path
    Write-Host "JDK trovato in: $env:JAVA_HOME"
} else {
    Write-Host "ERRORE: JDK non trovato nel sistema. Installare Java o impostare JAVA_HOME." -ForegroundColor Red
    exit 1
}

# Verifica e rilevamento automatico di PostgreSQL (psql)
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    # Cerca la cartella di installazione di PostgreSQL
    $pgBaseDir = "C:\Program Files\PostgreSQL"
    if (Test-Path $pgBaseDir) {
        $latestPg = Get-ChildItem $pgBaseDir -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latestPg -and (Test-Path "$($latestPg.FullName)\bin\psql.exe")) {
            $env:Path = "$($latestPg.FullName)\bin;" + $env:Path
            Write-Host "PostgreSQL trovato in: $($latestPg.FullName)"
        }
    }
}

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Host "ERRORE: 'psql' non e' stato trovato. Assicurarsi che PostgreSQL sia installato." -ForegroundColor Red
    exit 1
}

# 3. RILEVAMENTO DINAMICO PYTHON
if (-not (Get-Command python -ErrorAction SilentlyContinue) -or (Get-Command python).Source -like "*WindowsApps*") {
    # Cerca la cartella di installazione standard di Python in AppData o Program Files
    $pythonBase = "$env:LOCALAPPDATA\Programs\Python"
    if (Test-Path $pythonBase) {
        $latestPython = Get-ChildItem $pythonBase -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latestPython) {
            $env:Path = "$($latestPython.FullName);$($latestPython.FullName)\Scripts;" + $env:Path
            Write-Host "Python trovato in: $($latestPython.FullName)"
        }
    }
}