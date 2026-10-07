# Exerly API. Build from the repository root:
#   docker build -f apps/api/Dockerfile -t exerly-api .
# It needs DATABASE_URL and JWT_SECRET at run time and applies pending
# migrations before it listens.

FROM node:22-bookworm-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
# Scripts are skipped so the root's husky hook doesn't run; bcrypt loads its
# bundled Linux prebuild without an install step.
RUN npm ci --omit=dev --workspace apps/api --include-workspace-root=false --ignore-scripts \
  && mkdir -p apps/api/node_modules

FROM node:22-bookworm-slim
ENV NODE_ENV=production PORT=8080
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/api/node_modules ./apps/api/node_modules
COPY apps/api ./apps/api
USER node
WORKDIR /app/apps/api
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD node -e "fetch('http://127.0.0.1:' + process.env.PORT + '/api/health').then((r) => process.exit(r.ok ? 0 : 1), () => process.exit(1))"
CMD ["node", "index.js"]
