FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY src ./src
RUN apk add --no-cache wget && addgroup -S app && adduser -S app -G app
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["node", "src/server.js"]
