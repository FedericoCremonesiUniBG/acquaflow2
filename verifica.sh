#!/bin/bash

RADICE_PROGETTO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$RADICE_PROGETTO/django/.env"

if [ ! -f "$ENV_PATH" ]; then
    echo "File .env non trovato in django/. Completare prima il Passo 4 del manuale."
    exit 1
fi

DB_PASSWORD=$(grep '^DB_PASSWORD=' "$ENV_PATH" | cut -d '=' -f2-)
if [ -z "$DB_PASSWORD" ]; then
    echo "Impossibile leggere DB_PASSWORD da django/.env."
    exit 1
fi

echo "=== Verifica dell'integrità della migrazione ==="

CONTEGGI_REMOTI=$(curl -s http://distribuzioneacqua2.altervista.org/php/export/conteggio.php)
TUTTO_OK=true

verifica_tabella() {
    local chiave_json=$1
    local tabella_locale=$2
    local conteggio_remoto=$(echo "$CONTEGGI_REMOTI" | python3 -c "import sys, json; print(json.load(sys.stdin)['$chiave_json'])")
    local conteggio_locale=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U acquaflow_app -d acquaflow_locale -t -c "SELECT COUNT(*) FROM $tabella_locale;" | tr -d ' ')

    if [ "$conteggio_remoto" = "$conteggio_locale" ]; then
        echo "OK - $tabella_locale: locale=$conteggio_locale, remoto=$conteggio_remoto (corrispondono)"
    else
        echo "ATTENZIONE - $tabella_locale: locale=$conteggio_locale, remoto=$conteggio_remoto (NON corrispondono)"
        TUTTO_OK=false
    fi
}

verifica_tabella "clienti" "cliente"
verifica_tabella "punti_fornitura" "puntofornitura"
verifica_tabella "utenze" "utenza"
verifica_tabella "fatture" "fattura"
verifica_tabella "letture" "lettura"

echo ""
if [ "$TUTTO_OK" = true ]; then
    echo "Verifica completata: tutti i conteggi corrispondono."
else
    echo "ATTENZIONE: alcuni conteggi non corrispondono. Controllare la migrazione."
fi
