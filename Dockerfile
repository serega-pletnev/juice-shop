FROM node:20-alpine3.20

ENV NODE_ENV=production
WORKDIR /app

# Нужны git и совместимость с glibc (часто для бинарей npm)
RUN apk add --no-cache git libc6-compat

# Временные пакеты для node-gyp (снесём после install)
RUN apk add --no-cache --virtual .build-deps python3 make g++ pkgconf

COPY package*.json ./

# Ставим только прод-зависимости
RUN npm config set audit false && npm config set fund false \
 && if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi \
 && npm cache clean --force \
 && apk del .build-deps

COPY . .

EXPOSE 3000
CMD ["npm","start"]
