# ---------- Stage 1: builder ----------
FROM node:20-bookworm-slim AS builder
WORKDIR /app

# Инструменты для сборки нативных модулей и git-зависимостей
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

# 1) сначала только манифесты (лучший кеш слоёв)
COPY package*.json ./
COPY frontend/package*.json ./frontend/

# 2) ставим корневые зависимости БЕЗ lifecycle-скриптов
ENV npm_config_audit=false npm_config_fund=false
RUN npm ci --ignore-scripts --legacy-peer-deps

# 3) зависимости фронта без скриптов
RUN npm ci --ignore-scripts --legacy-peer-deps --prefix frontend

# 4) теперь копируем остальной код
COPY . .

# 5) даём отработать postinstall/пересборке уже при наличии проекта
RUN npm rebuild --unsafe-perm || true
RUN npm --prefix frontend rebuild --unsafe-perm || true

# 6) сборка (если есть соответствующие скрипты)
RUN npm run build --if-present || true
RUN npm --prefix frontend run build --if-present || true

# 7) отрезаем dev-зависимости и чистим кэш
RUN npm prune --omit=dev && npm cache clean --force

# ---------- Stage 2: runtime ----------
FROM node:20-bookworm-slim
ENV NODE_ENV=production
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# минимальный рантайм: прод-зависимости и собранные артефакты
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./

EXPOSE 3000
CMD ["npm","start"]
