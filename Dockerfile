# ---------- Stage 1: builder ----------
FROM node:20-bookworm-slim AS builder
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

# 1) только манифесты (кэш слоёв)
COPY package*.json ./
COPY frontend/package*.json ./frontend/

ENV npm_config_audit=false npm_config_fund=false

# 2) корневые зависимости (fallback на install, без скриптов)
RUN if [ -f package-lock.json ]; then \
      npm ci --ignore-scripts --legacy-peer-deps; \
    else \
      npm install --ignore-scripts --legacy-peer-deps; \
    fi

# 3) зависимости фронта (fallback, без скриптов)
RUN if [ -f frontend/package-lock.json ]; then \
      npm ci --ignore-scripts --legacy-peer-deps --prefix frontend; \
    else \
      npm install --ignore-scripts --legacy-peer-deps --prefix frontend; \
    fi

# 4) копируем остальной код
COPY . .

# 5) пересборка нативных модулей (когда проект уже на месте)
RUN npm rebuild --unsafe-perm || true
RUN npm --prefix frontend rebuild --unsafe-perm || true

# 6) сборка (если скрипты есть)
RUN npm run build --if-present || true
RUN npm --prefix frontend run build --if-present || true

# 7) оставляем только прод-зависимости
RUN npm prune --omit=dev && npm cache clean --force

# ---------- Stage 2: runtime ----------
FROM node:20-bookworm-slim
ENV NODE_ENV=production
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./

EXPOSE 3000
CMD ["npm","start"]
