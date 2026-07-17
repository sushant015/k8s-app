#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CMD="${1:-up}"

case "$CMD" in
  up)
    docker compose up --build -d
    echo ""
    echo "Waiting for frontend..."
    for i in $(seq 1 30); do
      if curl -sf http://localhost:8080/health >/dev/null 2>&1; then
        break
      fi
      sleep 5
    done
    echo ""
    echo "Vote Poll local stack is running:"
    echo "  App:      http://localhost:8080"
    echo "  Admin:    http://localhost:8080/admin/login"
    echo "  Login:    admin@votepoll.local / password"
    echo "  Postgres: localhost:5432 (user: votepoll, db: votepoll)"
    echo ""
    echo "Logs:  docker compose logs -f"
    echo "Down:  ./scripts/local-dev.sh down"
    ;;
  down)
    docker compose down
    ;;
  reset)
    docker compose down -v
    echo "Removed containers and postgres volume."
    ;;
  logs)
    docker compose logs -f "${2:-}"
    ;;
  ps)
    docker compose ps
    ;;
  *)
    echo "Usage: $0 {up|down|reset|logs [service]|ps}"
    exit 1
    ;;
esac
