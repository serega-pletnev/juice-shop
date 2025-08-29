FROM node:20-bookworm-slim

ENV NODE_ENV=production
WORKDIR /app

# Базовые пакеты без мусора
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git \
 && rm -rf /var/lib/apt/lists/*

# Копируем манифесты
COPY package*.json ./

# Временные зависимости для node-gyp (удалим после установки)
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ \
 && npm config set audit false && npm config set fund false \
 && if [ -f package-lock.json ]; then \
      npm ci --omit=dev --omit=optional; \
    else \
      npm install --omit=dev --omit=optional; \
    fi \
 && npm cache clean --force \
 && apt-get purge -y --auto-remove python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

# Остальной код
COPY . .

EXPOSE 3000
CMD ["npm","start"]
