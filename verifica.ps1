$ErrorActionPreference = "Stop"
$radiceProgetto = $PSScriptRoot

$envPath = "$radiceProgetto\django\.env"
if (-not (Test-Path $envPath)) {
    Write-Host "File .env non trovato in django\. Completare prima il Passo 4 del manuale."
    exit 1
}

$dbPassword = (Get-Content $envPath | Where-Object { $_ -match '^DB_PASSWORD=' }) -replace '^DB_PASSWORD=', ''
if (-not $dbPassword) {
    Write-Host "Impossibile leggere DB_PASSWORD da django\.env."
    exit 1
}

Write-Host "=== Verifica dell'integrita della migrazione ==="

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
    $risultatoPsql = psql -U acquaflow_app -d acquaflow_locale -t -c "SELECT COUNT(*) FROM $tabellaLocale;"
    $conteggioLocale = ($risultatoPsql -join "").Trim()

    if ("$conteggioRemoto" -eq "$conteggioLocale") {
        Write-Host "OK - $tabellaLocale : locale=$conteggioLocale, remoto=$conteggioRemoto (corrispondono)"
    } else {
        Write-Host "ATTENZIONE - $tabellaLocale : locale=$conteggioLocale, remoto=$conteggioRemoto (NON corrispondono)"
        $tuttoOk = $false
    }
}
Remove-Item Env:\PGPASSWORD

Write-Host ""
if ($tuttoOk) {
    Write-Host "Verifica completata: tutti i conteggi corrispondono."
} else {
    Write-Host "ATTENZIONE: alcuni conteggi non corrispondono. Controllare la migrazione."
}
