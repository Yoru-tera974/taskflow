FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

FROM node:18-alpine

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY app.js ./app.js
COPY package*.json ./

EXPOSE 8080

CMD ["node", "app.js"]