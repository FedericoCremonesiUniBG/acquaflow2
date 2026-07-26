#!/bin/bash
set -e

echo "Questo script installa/aggiorna i prerequisiti su Debian/Ubuntu (richiede una password di sistema)."
echo "Tomcat non è incluso: deve già essere presente, come da indicazioni del corso (versione 11)."
echo ""

sudo apt update
sudo apt install -y postgresql postgresql-contrib python3 python3-venv python3-pip python3-dev openjdk-17-jdk lsof curl libpq-dev build-essential

echo ""
echo "Prerequisiti installati/aggiornati. Ora è possibile eseguire ./install.sh <percorso-tomcat>"
