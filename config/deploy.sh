#!/bin/bash
# =============================================
# Script de deploiement automatise TaskFlow
# Usage : ./deploy.sh [dev|test|prod] [version]
# Exemple : ./deploy.sh prod v42
# =============================================

set -e  # Arreter en cas d'erreur

ENVIRONMENT=${1:-dev}
VERSION=${2:-latest}
ENV_FILE=".env.${ENVIRONMENT}"

# --- Validation ---
if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]]; then
    echo "Environnement invalide. Utiliser : dev, test ou prod"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Fichier $ENV_FILE introuvable"
    exit 1
fi

echo "========================================"
echo "Deploiement TaskFlow"
echo "Environnement : $ENVIRONMENT"
echo "Version       : $VERSION"
echo "========================================"

# --- Charger les variables d'environnement ---
export $(grep -v '^#' "$ENV_FILE" | xargs)
export VERSION=$VERSION

# --- Pull de la nouvelle image ---
echo "[1/4] Pull de l'image localhost:5000/taskflow:${VERSION}..."
docker pull localhost:5000/taskflow:${VERSION}

# --- Sauvegarde de la version actuelle (pour rollback) ---
CURRENT=$(docker inspect taskflow-${ENVIRONMENT} --format='{{.Config.Image}}' 2>/dev/null || echo "aucune")
echo "[2/4] Version actuelle : $CURRENT"

# --- Deploiement avec Docker Compose ---
echo "[3/4] Demarrage du nouveau conteneur..."
docker-compose --env-file "$ENV_FILE" up -d --no-deps app

# --- Verification sante ---
echo "[4/4] Verification sante..."
sleep 10
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT:-8080}/health)

if [ "$HEALTH" != "200" ]; then
    echo "ECHEC : health check retourne HTTP $HEALTH"
    echo "Rollback vers : $CURRENT"
    docker-compose --env-file "$ENV_FILE" down
    docker run -d --name taskflow-${ENVIRONMENT} \
        --env-file "$ENV_FILE" \
        -p ${PORT:-8080}:8080 \
        "$CURRENT"
    exit 1
fi

echo "========================================"
echo "Deploiement OK : HTTP $HEALTH"
echo "Version deployee : localhost:5000/taskflow:${VERSION}"
echo "========================================"
