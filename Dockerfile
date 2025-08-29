FROM node:20-alpine3.20

ENV NODE_ENV=production
WORKDIR /app

# Нужны для установки некоторых зависимостей и бинарей
RUN apk add --no-cache git libc6-compat

# Временные пакеты для node-gyp (удалим после install)
RUN apk add --no-cache --virtual .build-deps python3 make g++ pkgconf

COPY package*.json ./

# Ставим только прод-зависимости
RUN npm config set audit false && npm config set fund false \
 && if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi \
 && npm cache clean --force \
 # безопасное удаление: только если .build-deps существует
 && if apk info -e .build-deps >/dev/null 2>&1; then apk del --purge .build-deps; fi

COPY . .

EXPOSE 3000
CMD ["npm","start"]
