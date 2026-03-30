# ... Stages 1 and 2 stay at the top ...

# Stage 3: Final image
FROM node:22-alpine

# These tools need to be installed in the final image
RUN apk -U upgrade \
  && apk add bash python3 squid --no-cache

USER node
WORKDIR /app

# NOW we do the copies
COPY --from=server --chown=node:node /app/start.sh ./start.sh
COPY --from=server --chown=node:node /app/requirements.txt .
COPY --from=server --chown=node:node /app/healthcheck.js .

COPY --chown=node:node LICENSE.md .
COPY --chown=node:node ["LICENSES/PLANKA Community License DE.md", "LICENSE_DE.md"]

# These grab the compiled code from Stage 1 and Stage 2
COPY --from=server --chown=node:node /app/node_modules node_modules
COPY --from=server --chown=node:node /app/dist .
COPY --from=client --chown=node:node /app/dist public

RUN python3 -m venv .venv \
  && .venv/bin/pip3 install --upgrade pip \
  && .venv/bin/pip3 install -r requirements.txt --no-cache-dir \
  && mv .env.sample .env \
  && mv public/index.ejs views \
  && npm config set update-notifier false

VOLUME /app/data
EXPOSE 1337

RUN chmod +x ./start.sh

HEALTHCHECK --interval=10s --timeout=2s --start-period=15s \
  CMD node ./healthcheck.js

CMD ["./start.sh"]
