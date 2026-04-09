# ============================================================
# Dockerfile — TaskFlow Application
# TP Fil Rouge CI/CD — Noel Evan
# Adapté depuis le TP Infrastructure as Code (Nginx + Terraform)
# ============================================================

# Étape 1 — Build (installation des dépendances)
FROM node:18-alpine AS builder

WORKDIR /app

# Copie des fichiers de dépendances en premier (optimise le cache Docker)
COPY package*.json ./
RUN npm ci --only=production

# Étape 2 — Image finale légère
FROM node:18-alpine

# Métadonnées
LABEL maintainer="Noel Evan"
LABEL version="1.0"
LABEL description="TaskFlow - Application de gestion de tickets"

WORKDIR /app

# Copie des dépendances depuis le builder
COPY --from=builder /app/node_modules ./node_modules

# Copie du code source
COPY src/ ./src/

# Copie du frontend statique (hérité du TP IaC — dossier html/)
COPY html/ ./html/

# Copie des fichiers de configuration
COPY package.json ./

# Port exposé (identique au TP IaC : 8080)
EXPOSE 8080

# Health check intégré
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Démarrage de l'application
CMD ["node", "src/app.js"]
