#!/bin/bash
# ============================================================
# deploy.sh — Script de déploiement automatisé TaskFlow
# TP Fil Rouge CI/CD — Noel Evan
# Usage : ./deploy.sh [dev|test|prod] [version]
# Exemple : ./deploy.sh prod v42
# ============================================================

set -e  # Arrêt immédiat en cas d'erreur

# ---- Paramètres ----
ENV=${1:-test}
VERSION=${2:-latest}
REGISTRY=${REGISTRY:-localhost:5000}

# ---- Couleurs terminal ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Déploiement TaskFlow${NC}"
echo -e "${BLUE}  Environnement : ${YELLOW}$ENV${NC}"
echo -e "${BLUE}  Version       : ${YELLOW}$VERSION${NC}"
echo -e "${BLUE}  Registry      : ${YELLOW}$REGISTRY${NC}"
echo -e "${BLUE}================================================${NC}"

# ---- Validation de l'environnement ----
if [[ ! "$ENV" =~ ^(dev|test|prod)$ ]]; then
    echo -e "${RED}ERREUR : Environnement invalide. Valeurs acceptées : dev, test, prod${NC}"
    exit 1
fi

if [ ! -f ".env.$ENV" ]; then
    echo -e "${RED}ERREUR : Fichier .env.$ENV introuvable${NC}"
    exit 1
fi

# ---- Chargement des variables d'environnement ----
source .env.$ENV
echo -e "${GREEN}✓ Configuration chargée depuis .env.$ENV${NC}"

# ---- Détermination du port selon l'env ----
case $ENV in
  dev)  HOST_PORT=${PORT:-8082} ;;
  test) HOST_PORT=${PORT:-8081} ;;
  prod) HOST_PORT=${PORT:-80}   ;;
esac

CONTAINER_NAME="taskflow-$ENV"

# ---- Pull de la nouvelle image ----
echo -e "${YELLOW}--- Pull image $REGISTRY/taskflow:$VERSION ...${NC}"
docker pull $REGISTRY/taskflow:$VERSION
echo -e "${GREEN}✓ Image récupérée${NC}"

# ---- Sauvegarde de l'ancienne version (pour rollback) ----
OLD_VERSION=$(docker inspect $CONTAINER_NAME --format '{{.Config.Image}}' 2>/dev/null || echo "aucune")
echo -e "${YELLOW}--- Ancienne version : $OLD_VERSION${NC}"

# ---- Arrêt du conteneur existant ----
echo -e "${YELLOW}--- Arrêt du conteneur existant...${NC}"
docker stop $CONTAINER_NAME 2>/dev/null || echo "Aucun conteneur actif"
docker rm   $CONTAINER_NAME 2>/dev/null || true

# ---- Démarrage du nouveau conteneur ----
echo -e "${YELLOW}--- Démarrage taskflow:$VERSION sur port $HOST_PORT ...${NC}"
docker run -d \
  --name $CONTAINER_NAME \
  --env-file .env.$ENV \
  -p ${HOST_PORT}:8080 \
  --restart unless-stopped \
  $REGISTRY/taskflow:$VERSION

echo -e "${GREEN}✓ Conteneur démarré${NC}"

# ---- Health Check ----
echo -e "${YELLOW}--- Health check (attente 5s)...${NC}"
sleep 5

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${HOST_PORT}/health 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  SUCCESS : TaskFlow $VERSION déployé !${NC}"
    echo -e "${GREEN}  Environnement : $ENV${NC}"
    echo -e "${GREEN}  URL : http://localhost:${HOST_PORT}${NC}"
    echo -e "${GREEN}================================================${NC}"
else
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}  ÉCHEC : Health check KO (HTTP $HTTP_CODE)${NC}"
    echo -e "${RED}  Rollback vers : $OLD_VERSION${NC}"
    echo -e "${RED}================================================${NC}"

    # Rollback automatique
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm   $CONTAINER_NAME 2>/dev/null || true

    if [ "$OLD_VERSION" != "aucune" ]; then
        docker run -d \
          --name $CONTAINER_NAME \
          --env-file .env.$ENV \
          -p ${HOST_PORT}:8080 \
          --restart unless-stopped \
          $OLD_VERSION
        echo -e "${YELLOW}Rollback effectué vers $OLD_VERSION${NC}"
    fi

    exit 1
fi
