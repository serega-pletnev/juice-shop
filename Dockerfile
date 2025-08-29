# Минимальный прод-рантайм на актуальном Alpine (обычно меньше CVE)
FROM node:20-alpine3.20

ENV NODE_ENV=production
WORKDIR /app

# Ставим только прод-зависимости (если нет lock-файла — fallback на install)
COPY package*.json ./
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi \
 && npm cache clean --force

# Копируем остальной код
COPY . .

EXPOSE 3000
# у Juice Shop есть скрипт start — используем его
CMD ["npm","start"]
