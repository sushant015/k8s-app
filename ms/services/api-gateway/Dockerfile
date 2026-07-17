FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY src ./src

FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache wget && addgroup -S app && adduser -S app -G app
COPY --from=build /app /app
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["node", "src/index.js"]
