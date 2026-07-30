param(
    [string]$TomcatPath
)

Write-Host "Controllo dei prerequisiti installati sul sistema."
Write-Host "Questo script puo' essere eseguito da qualsiasi cartella: non fa riferimento a file del progetto."
Write-Host ""

Write-Host "--- Python (richiesto: 3.12 o successiva) ---"
if (Get-Command python -ErrorAction SilentlyContinue) {
    python --version
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    py --version
} else {
    Write-Host "Non trovato." -ForegroundColor Red
}
Write-Host ""

Write-Host "--- Java (richiesto: JDK 17 o successiva) ---"
if (Get-Command java -ErrorAction SilentlyContinue) {
    $versioneJava = cmd /c "java -version 2>&1"
    Write-Host ($versioneJava -join "`n")
} else {
    Write-Host "Non trovato." -ForegroundColor Red
}
Write-Host ""

Write-Host "--- PostgreSQL (richiesta: qualsiasi versione recente) ---"
if (Get-Command psql -ErrorAction SilentlyContinue) {
    psql --version
} else {
    Write-Host "Non trovato." -ForegroundColor Red
}
Write-Host ""

Write-Host "--- Git ---"
if (Get-Command git -ErrorAction SilentlyContinue) {
    git --version
} else {
    Write-Host "Non trovato." -ForegroundColor Red
}
Write-Host ""

Write-Host "--- Apache Tomcat (richiesta: versione 11 o successiva compatibile con Jakarta Servlet 6.1) ---"
if ($TomcatPath) {
    if (Test-Path "$TomcatPath\bin\version.bat") {
        Push-Location "$TomcatPath\bin"
        .\version.bat
        Pop-Location
    } else {
        Write-Host "Percorso specificato non valido: $TomcatPath" -ForegroundColor Red
    }
} else {
    Write-Host "Percorso non specificato (facoltativo). Per controllarlo: .\controlla_prerequisiti.ps1 -TomcatPath <percorso>"
}
