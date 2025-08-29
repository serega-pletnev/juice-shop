# ---------- Stage 1: builder ----------
FROM node:20-bookworm-slim AS builder
WORKDIR /app

# Инструменты для сборки нативных модулей
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

# Переносим ВСЁ сразу, чтобы lifecycle-скрипты видели папку frontend/
COPY . .

# Полная установка dev+prod для сборки
RUN npm ci

# Сборка (если в проекте есть соответствующие скрипты)
# Для Juice Shop обычно достаточно стандартного build; на всякий случай пытаемся и сервер
RUN npm run build --if-present || npm run build:frontend --if-present || true
RUN npm run build:server --if-present || true

# Оставляем только прод-зависимости
RUN npm prune --omit=dev && npm cache clean --force

# ---------- Stage 2: runtime ----------
FROM node:20-bookworm-slim
ENV NODE_ENV=production
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Берём готовые node_modules и собранные артефакты из builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./

EXPOSE 3000
CMD ["npm","start"]
