# Built by .github/workflows/deploy.yml (context ., file Dockerfile) and pushed
# to Artifact Registry. Adapted from the fleet's nextjs stack pack.
#
# Deviations from the pack, and why:
#   - `npm install` when no lockfile is committed; the pack assumes `npm ci`.
#   - next.config sets `output: "standalone"`, which the pack's runtime stage
#     requires (.next/standalone) but the stock config does not enable.

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1 SKIP_ENV_VALIDATION=1
RUN npm run build

FROM node:22-alpine AS runtime
ARG BUILD_ID=""
WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3000 HOSTNAME=0.0.0.0 BUILD_ID=$BUILD_ID
RUN addgroup -S app && adduser -S app -G app
COPY --from=build --chown=app:app /app/public ./public
COPY --from=build --chown=app:app /app/.next/standalone ./
COPY --from=build --chown=app:app /app/.next/static ./.next/static
# KEEP THIS: one log line per request (status + duration) is what the workspace Monitoring tab charts.
# request-log.cjs is preloaded by the CMD below (`node -r ./request-log.cjs`).
COPY --chown=app:app request-log.cjs ./
USER app
EXPOSE 3000
CMD ["node", "-r", "./request-log.cjs", "server.js"]
