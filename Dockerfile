# ---------- Builder Stage ----------
FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

WORKDIR /evolution

# Copy package files first (for caching)
COPY package*.json ./
COPY tsconfig.json ./

RUN npm install

# Copy source code
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY runWithProvider.js tsup.config.ts ./
COPY ./Docker ./Docker

# Make scripts executable and format correctly
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# Initialize database (dev only — move to CI/CD in prod if needed)
RUN ./Docker/scripts/generate_database.sh

# Build the TypeScript project
RUN npm run build

# ---------- Final Runtime Stage ----------
FROM node:20-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

# Copy only what's needed from builder
COPY --from=builder /evolution/package.json ./
COPY --from=builder /evolution/package-lock.json ./
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/runWithProvider.js ./
COPY --from=builder /evolution/tsup.config.ts ./
COPY --from=builder /evolution/Docker ./Docker

# Optional: Create non-root user
# RUN addgroup -S app && adduser -S app -G app
# USER app

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod"]
