# ---- deps: install all dependencies (prisma schema needed for postinstall) ----
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
COPY prisma ./prisma
# --include=dev: PaaS como o Coolify injetam NODE_ENV=production no build, o que
# faria o npm pular as devDependencies necessárias para compilar (nest cli, tsc).
RUN npm ci --include=dev

# ---- build: generate prisma client and compile ----
FROM node:24-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate && npm run build

# ---- runner: production-only artifacts ----
FROM node:24-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
COPY prisma ./prisma
COPY --from=build /app/node_modules ./node_modules
RUN npm prune --omit=dev && npm cache clean --force
# npm prune drops the generated client; restore it
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /app/node_modules/@prisma/client ./node_modules/@prisma/client
COPY --from=build /app/dist ./dist
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh
EXPOSE 3000
# wget (busybox) em vez de curl: a imagem alpine não traz curl e o healthcheck
# padrão do Coolify o usa, marcando o container unhealthy com a API saudável.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://localhost:3000/health >/dev/null 2>&1 || exit 1
# migrate deploy no boot (exige a CLI do prisma em dependencies) + seed opcional
CMD ["./docker-entrypoint.sh"]
