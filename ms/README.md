# Vote Polling Platform — Multi-Microservice Architecture on GKE

Private, highly available vote polling system with **no public IPs** on GKE, Cloud SQL, or the frontend.

## Architecture Overview

```mermaid
flowchart TB
    subgraph corp["Corporate Network / VPN / Cloud IAP"]
        Admin[Admin Browser]
        Voter[Anonymous Voter Browser]
    end

    subgraph vpc["Private VPC (no public endpoints)"]
        ILB[Internal HTTP(S) Load Balancer]

        subgraph gke["Private GKE Cluster"]
            FE[frontend-service<br/>Node.js]
            GW[api-gateway<br/>Node.js]
            AUTH[auth-service<br/>Spring Boot]
            USER[user-service<br/>Node.js]
            POLL[poll-service<br/>Spring Boot]
            VOTE[vote-service<br/>Node.js]
            RES[result-service<br/>Python FastAPI]
        end

        SQL[(Cloud SQL PostgreSQL<br/>Private IP only)]
    end

    Admin --> ILB
    Voter --> ILB
    ILB --> FE
    FE --> GW
    GW --> AUTH
    GW --> USER
    GW --> POLL
    GW --> VOTE
    GW --> RES
    AUTH --> SQL
    USER --> SQL
    POLL --> SQL
    VOTE --> SQL
    RES --> SQL
```

## Microservices

| Service | Stack | Responsibility |
|---------|-------|----------------|
| `frontend-service` | Node.js | Admin dashboard + anonymous poll pages (SPA) |
| `api-gateway` | Node.js | Routing, rate limiting, JWT validation passthrough |
| `auth-service` | Spring Boot | Admin login, JWT issue/validate |
| `user-service` | Node.js | Admin user CRUD |
| `poll-service` | Spring Boot | Poll CRUD, options, validity window, publish |
| `vote-service` | Node.js | Anonymous vote submission, duplicate prevention |
| `result-service` | Python | Aggregate votes, compute percentages, publish |

## Roles

### Admin
- Login via `/admin/login`
- Create polls with options and validity (`start_at`, `end_at`)
- View live results during poll
- Publish final results when poll ends

### Anonymous User
- Access unique poll URL: `/poll/{pollSlug}`
- Vote once per poll during validity window
- After poll ends, same URL shows published results

## Security & HA Design

1. **Private GKE** — `enable-private-nodes`, private control plane endpoint, no public node IPs
2. **Private Cloud SQL** — Private Service Connect / VPC peering, no public IP
3. **Internal Load Balancer only** — Frontend reachable only from VPC/VPN/IAP
4. **Cloud NAT** — Outbound internet for image pulls only (Artifact Registry)
5. **Pod Disruption Budgets** — Minimum availability during node upgrades
6. **HPA** — Auto-scale gateway, vote, and poll services under load
7. **Multi-replica Deployments** — Minimum 2 replicas per stateless service
8. **Cloud SQL HA** — Regional HA instance with automatic failover
9. **Health checks** — Liveness/readiness on every service

## Database (Cloud SQL PostgreSQL)

Single instance, schema-per-service:

- `auth` — admin credentials, refresh tokens
- `users` — admin profiles
- `polls` — polls, options, status
- `votes` — vote records with voter fingerprint hash
- `results` — aggregated snapshots, publish state

See `database/init.sql`.

## Local Development (Docker Compose)

Run the full stack on your machine without GCP or GKE. Requires **Docker Desktop** (or Docker Engine + Compose v2).

```bash
cd ms
chmod +x scripts/local-dev.sh

# Start all services (first run builds images — Spring Boot takes ~2–3 min)
./scripts/local-dev.sh up

# Or manually:
docker compose up --build
```

**Access**

| URL | Purpose |
|-----|---------|
| http://localhost:8080 | Frontend (admin + voter pages) |
| http://localhost:8080/admin/login | Admin login |
| http://localhost:8080/poll/{slug} | Anonymous voting page |
| localhost:5432 | PostgreSQL (user: `votepoll`, password: `changeme`) |

**Default admin credentials:** `admin@votepoll.local` / `password`

**Useful commands**

```bash
./scripts/local-dev.sh logs          # all service logs
./scripts/local-dev.sh logs poll-service
./scripts/local-dev.sh ps            # container status
./scripts/local-dev.sh down          # stop stack
./scripts/local-dev.sh reset         # stop + wipe DB volume
```

**Local smoke test**

1. Open http://localhost:8080/admin/login and sign in.
2. Create a poll with slug `team-lunch`, set start/end times around now.
3. Open http://localhost:8080/poll/team-lunch and submit a vote.
4. After end time (or click **Publish** on dashboard), view results on the same poll URL.

## Quick Start (GKE / Production)

```bash
# 1. Provision GCP infrastructure (run in Cloud Shell)
chmod +x ms/infra/gcloud-setup.sh
./ms/infra/gcloud-setup.sh

# 2. Build and push images (after Artifact Registry is created)
export PROJECT_ID=your-project REGION=us-central1
./ms/scripts/build-and-push.sh

# 3. Deploy to GKE
kubectl apply -f ms/k8s/

# 4. Access via internal LB IP (from VPN/bastion)
kubectl get svc -n vote-poll frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## API Routes (via Gateway)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/login` | — | Admin login |
| GET | `/api/users/me` | JWT | Current admin profile |
| POST | `/api/polls` | JWT | Create poll |
| GET | `/api/polls` | JWT | List admin polls |
| GET | `/api/polls/{slug}` | — | Public poll info |
| POST | `/api/polls/{slug}/vote` | — | Submit vote |
| GET | `/api/polls/{slug}/results` | — | Get results (if published or ended) |
| POST | `/api/polls/{id}/publish` | JWT | Publish results |

## Folder Layout

```
ms/
├── README.md
├── docker-compose.yml      # Local dev stack
├── .env.example
├── database/init.sql
├── infra/gcloud-setup.sh
├── scripts/
│   ├── build-and-push.sh
│   ├── deploy.sh
│   └── local-dev.sh
├── k8s/                    # Kubernetes manifests
└── services/               # Microservice source code
```
## Troubleshooting 

1. Check direct authentication from Auth Service

```
docker exec vote-poll-auth-service-1 wget -S -O - --post-data='{"email":"admin@votepoll.local", "password":"Sushant@12"}' --header='Content-Type: application/json' http://localhost:8080/api/auth/login

## Command to down running docker with volumes and starts again
docker-compose down -v   
./scripts/local-dev.sh up

```
2. Check authentication from api-gateway endpoint
- Verify the logs for url mapping (api/auth/login on api-getway should map api/auth/login on auth service)

```
curl -X POST http://localhost:8081/api/auth/login -H "Content-Type: application/json" -d '{"email":"admin@votepoll.local", "password":"Sushant@12"}' -v

docker image rm vote-poll-frontend:latest
docker image rm vote-poll-api-gateway:latest
docker image ls
```

3. Is the API Gateway actually listening on 8081 inside Docker?
If your API Gateway container is configured like this:

```
api-gateway:
  ports:
    - "8081:8080"
```

then:

Outside Docker (your Mac): use http://localhost:8081
Inside Docker (another container): use http://api-gateway:8080
Containers communicate over the container's internal port, not the host-mapped port.

```
docker exec -it vote-poll-frontend-1 sh

## If that succeeds, your internal networking is correct.
wget -S -O - http://api-gateway:8080/health

## This should usually fail unless the gateway is actually listening on 8081 inside the container.
wget -S -O - http://api-gateway:8081/health

```