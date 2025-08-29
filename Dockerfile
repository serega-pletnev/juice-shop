FROM node:20-alpine3.20

ENV NODE_ENV=production
WORKDIR /app

# Нужно git (и только при необходимости node-gyp: python3 make g++)
RUN apk add --no-cache git

COPY package*.json ./

# Устанавливаем только прод-зависимости
RUN npm config set audit false && npm config set fund false \
 && if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi \
 && npm cache clean --force

COPY . .

EXPOSE 3000
CMD ["npm","start"]
