#!/bin/bash
set -e

TOMCAT_PATH="$1"
if [ -z "$TOMCAT_PATH" ]; then
    echo "Uso: ./install.sh <percorso-tomcat>"
    echo "Esempio: ./install.sh ~/apache-tomcat-10.1.26"
    exit 1
fi
if [ ! -d "$TOMCAT_PATH" ]; then
    echo "Percorso Tomcat non valido: $TOMCAT_PATH"
    exit 1
fi

echo "Verifica prerequisiti..."
MANCA_QUALCOSA=false
for cmd in python3 java psql curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Manca: $cmd"
        MANCA_QUALCOSA=true
    fi
done
if [ "$MANCA_QUALCOSA" = true ]; then
    echo ""
    echo "Alcuni prerequisiti non risultano installati."
    echo "Consultare la sezione Prerequisiti del manuale per le istruzioni di installazione."
    exit 1
fi

RADICE_PROGETTO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Arresto di eventuali istanze precedenti..."
PID_DJANGO=$(lsof -ti:8000 2>/dev/null || true)
if [ -n "$PID_DJANGO" ]; then
    kill -9 $PID_DJANGO 2>/dev/null || true
    echo "Istanza precedente di Django arrestata."
fi

if [ -f "$TOMCAT_PATH/bin/shutdown.sh" ]; then
    "$TOMCAT_PATH/bin/shutdown.sh" 2>/dev/null || true
    sleep 3
fi

echo "=== Passo 1/7: Creazione utente e database PostgreSQL ==="
DB_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)

read -s -p "Inserisci la password dell'utente postgres (database): " POSTGRES_PASSWORD
echo ""
export PGPASSWORD="$POSTGRES_PASSWORD"

psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS acquaflow_locale;"
psql -h localhost -U postgres -c "DROP USER IF EXISTS acquaflow_app;"
psql -h localhost -U postgres -c "CREATE USER acquaflow_app WITH PASSWORD '$DB_PASSWORD';"
psql -h localhost -U postgres -c "CREATE DATABASE acquaflow_locale OWNER acquaflow_app;"
psql -h localhost -U postgres -d acquaflow_locale -c "GRANT ALL ON SCHEMA public TO acquaflow_app;"
psql -h localhost -U postgres -d acquaflow_locale -c "ALTER SCHEMA public OWNER TO acquaflow_app;"
unset PGPASSWORD

PGPASSWORD="$DB_PASSWORD" psql -h localhost -U acquaflow_app -d acquaflow_locale -f "$RADICE_PROGETTO/db/schema_postgres.sql"

echo "=== Passo 2/7: Configurazione credenziali ==="
cat > "$RADICE_PROGETTO/django/.env" << EOF
DB_NAME=acquaflow_locale
DB_USER=acquaflow_app
DB_PASSWORD=$DB_PASSWORD
DB_HOST=localhost
DB_PORT=5432
EOF

echo "=== Passo 3/7: Preparazione ambiente Python ==="
cd "$RADICE_PROGETTO/django"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt --quiet
python manage.py migrate

echo "=== Passo 4/7: Avvio del web-service Django ==="
nohup python manage.py runserver > django.log 2>&1 &
disown
sleep 5

echo "=== Passo 5/7: Compilazione della Servlet ==="
cd "$RADICE_PROGETTO/servlet"
chmod +x ./mvnw
./mvnw clean package

echo "=== Passo 6/7: Distribuzione su Tomcat ==="
cp "$RADICE_PROGETTO/servlet/target/migrazione.war" "$TOMCAT_PATH/webapps/migrazione.war"
rm -rf "$TOMCAT_PATH/webapps/migrazione"
"$TOMCAT_PATH/bin/startup.sh"

echo "In attesa che Tomcat sia pronto..."
TOMCAT_PRONTO=false
for i in $(seq 1 30); do
    if curl -s -o /dev/null http://localhost:8080; then
        TOMCAT_PRONTO=true
        break
    fi
    sleep 2
done

if [ "$TOMCAT_PRONTO" = false ]; then
    echo "Tomcat non risulta ancora pronto dopo 60 secondi."
    echo "Attendere qualche secondo, poi visitare manualmente: http://localhost:8080/migrazione/migra"
    exit 1
fi

echo "=== Passo 7/7: Avvio della migrazione ==="
echo "Migrazione in corso: può richiedere circa un minuto, a seconda della velocità della connessione. Non chiudere questa finestra."
curl http://localhost:8080/migrazione/migra

echo ""
echo "=== Verifica automatica dell'integrità della migrazione ==="

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

echo ""
echo "Installazione completata."
