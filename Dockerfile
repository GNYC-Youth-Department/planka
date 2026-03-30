# ==========================================
# Stage 1: Server build
# ==========================================
FROM node:22-alpine AS server

RUN apk -U upgrade \
  && apk add build-base python3 --no-cache

WORKDIR /app

# Copy the server source code
COPY server .

# Install dependencies and build the server
RUN npm install \
  && npm run build \
  && npm prune --production


# ==========================================
# Stage 2: Client build
# ==========================================
FROM node:22 AS client

WORKDIR /app

# Copy the client source code (contains your GNYC logos/colors)
COPY client .

# Build the frontend assets
RUN npm install --omit=dev \
  && INDEX_FORMAT=ejs DISABLE_ESLINT_PLUGIN=true npm run build


# ==========================================
# Stage 3: Final image (The one that runs on your VPS)
# ==========================================
FROM node:22-alpine

# Install production-only system dependencies
RUN apk -U upgrade \
  && apk add bash python3 squid --no-cache

# Switch to the non-root 'node' user for security
USER node
WORKDIR /app

# 1. Copy root-level scripts and configs from the server stage
COPY --from=server --chown=node:node /app/start.sh ./start.sh
COPY --from=server --chown=node:node /app/requirements.txt .
COPY --from=server --chown=node:node /app/healthcheck.js .

# 2. Copy legal files
COPY --chown=node:node LICENSE.md .
COPY --chown=node:node ["LICENSES/PLANKA Community License DE.md", "LICENSE_DE.md"]

# 3. Copy compiled application files
COPY --from=server --chown=node:node /app/node_modules node_modules
COPY --from=server --chown=node:node /app/dist .

# 4. Copy the branded frontend into the public folder
COPY --from=client --chown=node:node /app/dist public

# 5. Setup Python environment and finalize folder structure
RUN python3 -m venv .venv \
  && .venv/bin/pip3 install --upgrade pip \
  && .venv/bin/pip3 install -r requirements.txt --no-cache-dir \
  && mv .env.sample .env \
  && mv public/index.ejs views \
  && npm config set update-notifier false \
  && chmod +x ./start.sh

# Persistence and Networking
VOLUME /app/data
EXPOSE 1337

# Healthcheck configuration
HEALTHCHECK --interval=10s --timeout=2s --start-period=15s \
  CMD node ./healthcheck.js

# Launch the app
CMD ["./start.sh"]
