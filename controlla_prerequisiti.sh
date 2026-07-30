#!/bin/bash

ROSSO='\033[0;31m'
RESET='\033[0m'

TOMCAT_PATH="$1"

echo "Controllo dei prerequisiti installati sul sistema."
echo "Questo script può essere eseguito da qualsiasi cartella: non fa riferimento a file del progetto."
echo ""

echo "--- Python (richiesto: 3.12 o successiva) ---"
if command -v python3 &> /dev/null; then
    python3 --version
else
    echo -e "${ROSSO}Non trovato. Si prega di procedere al download.${RESET}"
fi
echo ""

echo "--- Java (richiesto: JDK 17 o successiva) ---"
if command -v java &> /dev/null; then
    java -version 2>&1
else
    echo -e "${ROSSO}Non trovato. Si prega di procedere al download.${RESET}"
fi
echo ""

echo "--- PostgreSQL (richiesta: qualsiasi versione recente) ---"
if command -v psql &> /dev/null; then
    psql --version
else
    echo -e "${ROSSO}Non trovato. Si prega di procedere al download.${RESET}"
fi
echo ""

echo "--- Git ---"
if command -v git &> /dev/null; then
    git --version
else
    echo -e "${ROSSO}Non trovato. Si prega di procedere al download.${RESET}"
fi
echo ""

echo "--- Apache Tomcat (richiesta: versione 11 o successiva compatibile con Jakarta Servlet 6.1) ---"
if [ -n "$TOMCAT_PATH" ]; then
    if [ -f "$TOMCAT_PATH/bin/version.sh" ]; then
        "$TOMCAT_PATH/bin/version.sh"
    else
        echo -e "${ROSSO}Percorso specificato non valido: $TOMCAT_PATH${RESET}"
    fi
else
    echo "Percorso non specificato (facoltativo). Per controllarlo: ./controlla_prerequisiti.sh <percorso>"
fi
