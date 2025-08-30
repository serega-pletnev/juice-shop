FROM node:20-bookworm-slim AS deps
WORKDIR /app
COPY package*.json ./
RUN npm config set audit false \
 && npm config set fund false \
 && apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ \
 && if [ -f package-lock.json ]; then npm ci --omit=dev; else npm i --omit=dev; fi \
 && apt-get purge -y --auto-remove python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

FROM node:20-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app /app
COPY . .
EXPOSE 3000
CMD ["npm","start"]
