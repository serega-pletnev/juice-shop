# ---------- Stage 1: builder ----------
FROM node:20-bookworm-slim AS builder
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

# 1) сперва только манифесты (чтоб кеш слоёв работал)
COPY package*.json ./
COPY frontend/package*.json ./frontend/ 2>/dev/null || true

ENV npm_config_audit=false npm_config_fund=false

# 2) корневые зависимости БЕЗ скриптов, с fallback на install при отсутствии lock
RUN if [ -f package-lock.json ]; then \
      npm ci --ignore-scripts --legacy-peer-deps; \
    else \
      npm install --ignore-scripts --legacy-peer-deps; \
    fi

# 3) зависимости фронта (если есть), тоже с fallback
RUN if [ -d frontend ]; then \
      if [ -f frontend/package-lock.json ]; then \
        npm ci --ignore-scripts --legacy-peer-deps --prefix frontend; \
      else \
        npm install --ignore-scripts --legacy-peer-deps --prefix frontend; \
      fi; \
    fi

# 4) теперь копируем остальной код
COPY . .

# 5) пересборка нативных модулей (теперь проект уже на месте)
RUN npm rebuild --unsafe-perm || true
RUN if [ -d frontend ]; then npm --prefix frontend rebuild --unsafe-perm || true; fi

# 6) сборка (если скрипты есть)
RUN npm run build --if-present || true
RUN if [ -d frontend ]; then npm --prefix frontend run build --if-present || true; fi

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
