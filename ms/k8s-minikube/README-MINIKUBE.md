# Minikube Kubernetes Configuration with PostgreSQL

This directory contains Kubernetes manifests for running the Vote-Poll application locally on Minikube with a self-hosted PostgreSQL database.

## Difference from Cloud (k8s/) Configuration

| Aspect | Minikube (k8s-minikube/) | Cloud (k8s/) |
|--------|--------------------------|--------------|
| **Database** | Local PostgreSQL Deployment | Google Cloud SQL |
| **Secrets** | Minikube secrets file | Cloud secret management |
| **Image Registry** | Local Docker images | Artifact Registry |
| **Network Policies** | Permissive (dev-friendly) | Strict IP-based policies |
| **Storage** | Local PVC (5Gi) | Cloud Storage |
| **Resource Limits** | Minimal | Production-grade |

## File Structure

```
k8s-minikube/
├── 00-namespace.yaml           # Create vote-poll namespace
├── 01-configmap.yaml           # Config with service URLs and DB settings
├── 02-postgres-db.yaml         # PostgreSQL Deployment + Service + PVC + Init Script
├── 02-secrets.yaml             # Database credentials and JDBC URLs
├── 10-api-gateway.yaml         # API Gateway deployment
├── 11-auth-service.yaml        # Authentication service
├── 12-user-service.yaml        # User service
├── 13-poll-service.yaml        # Poll service
├── 14-vote-service.yaml        # Vote service
├── 15-result-service.yaml      # Result service
├── 16-frontend-service.yaml    # Frontend UI
├── 20-pod-disruption-budgets.yaml
├── 22-network-policies.yaml    # Network policies
└── README.md                    # This file
```

## Quick Start

### Prerequisites

1. Install Minikube: https://minikube.sigs.k8s.io/docs/start/
2. Start Minikube:
   ```bash
   minikube start --cpus=4 --memory=4096
   ```

3. Enable storage provisioner:
   ```bash
   minikube addons enable storage-provisioner
   ```

### Deploy to Minikube

The recommended way to deploy the entire application is to use the automated build script. This script handles building images, loading them into Minikube, and deploying all services with zero-downtime rolling updates.

1.  **Run the Full Build & Deploy Script:**
    Navigate to the project root directory and execute the script.

    ```bash
    # Make the script executable
    chmod +x ms/scripts/build-and-push-minikube.sh

    # Run the script
    ./ms/scripts/build-and-push-minikube.sh
    ```

2.  **For a Single Service Update:**
    If you only changed one service, you can use the `quick-build.sh` script for a much faster update.

   ```bash
    ./ms/scripts/quick-build.sh <service-name>
    # Example: ./ms/scripts/quick-build.sh poll-service
   ```

### Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n vote-poll

# Check services
kubectl get svc -n vote-poll

# Check PostgreSQL logs
kubectl logs -n vote-poll -l app=postgres-db -f

# Access PostgreSQL from local machine
kubectl port-forward -n vote-poll svc/postgres-db 5432:5432
psql -h localhost -U postgres -d postgres -c "\l"  # List databases
```

## Database Configuration

### PostgreSQL Details

- **Host:** `postgres-db` (within cluster)
- **Port:** `5432`
- **Username:** `postgres`
- **Password:** `postgres_password` (see `02-secrets.yaml`)
- **Storage:** 5Gi persistent volume

### Schemas Created

The `postgres-initdb` ConfigMap creates the following schemas in the shared `postgres` database automatically:

- `auth` - Authentication service tables
- `users` - User profile service tables
- `polls` - Poll management service tables
- `votes` - Voting service tables
- `results` - Results aggregation tables

### Connection URLs

Each microservice connects to the shared `postgres` database and uses its own schema:

- Auth Service: `jdbc:postgresql://postgres-db:5432/postgres?currentSchema=auth`
- User Service: `postgresql://postgres:postgres_password@postgres-db:5432/postgres`
- Poll Service: `jdbc:postgresql://postgres-db:5432/postgres?currentSchema=polls`
- Vote Service: `postgresql://postgres:postgres_password@postgres-db:5432/postgres`
- Result Service: `postgresql://postgres:postgres_password@postgres-db:5432/postgres`

## Access Services

### Local Access

1. **API Gateway:**
   ```bash
   kubectl port-forward -n vote-poll svc/api-gateway 8080:8080
   # Access: http://localhost:8080
   ```

2. **Frontend:**
   ```bash
   kubectl port-forward -n vote-poll svc/frontend-service 3000:3000
   # Access: http://localhost:3000
   ```

3. **PostgreSQL:**
   ```bash
   kubectl port-forward -n vote-poll svc/postgres-db 5432:5432
   # Access: psql -h localhost -U postgres
   ```

### Minikube Ingress

Enable Minikube ingress addon:
```bash
minikube addons enable ingress
```

Then create an Ingress resource to expose services.

## Cleanup

Remove all resources:
```bash
kubectl delete namespace vote-poll
```

## Network Policies

The `22-network-policies.yaml` contains minikube-friendly network policies:
- Default deny ingress
- Allow frontend from any pod in namespace
- Allow gateway from frontend
- Allow backend services from gateway

These are more permissive than production policies for easier development.

## Important Notes

### For Development Only

- The secrets in `02-secrets.yaml` contain default credentials
- JWT_SECRET is a placeholder - change in production
- Database password is hardcoded - use proper secret management in production
- No backups are configured - data is lost when PVC is deleted

### Differences from Production (k8s/)

1. **Database:** Uses local PostgreSQL instead of Cloud SQL
2. **Connection:** Uses internal Kubernetes DNS (`postgres-db`)
3. **Storage:** Local minikube storage instead of Cloud Storage
4. **Secrets:** Git-tracked for convenience (NEVER do this in production)
5. **Network Policies:** Permissive for easier debugging

## Troubleshooting

### PostgreSQL Pod Not Ready

```bash
# Check logs
kubectl logs -n vote-poll -l app=postgres-db

# Check PVC
kubectl get pvc -n vote-poll

# Check events
kubectl describe pod -n vote-poll -l app=postgres-db
```

### Cannot Connect to PostgreSQL

1. Verify PostgreSQL pod is running: `kubectl get pods -n vote-poll`
2. Check service DNS: `kubectl exec -it <pod> -- nslookup postgres-db`
3. Test connectivity from another pod:
   ```bash
   kubectl run -it --rm debug --image=postgres:15-alpine --restart=Never -- \
     psql -h postgres-db -U postgres -c "SELECT 1"
   ```

### Microservice Database Connection Issues

1. Check secrets are mounted: `kubectl describe pod -n vote-poll <service-pod>`
2. Check JDBC URL format in environment variables
3. Verify database names match in ConfigMap and init script
4. Check microservice logs: `kubectl logs -n vote-poll -l app=<service>`

## References

- Kubernetes Documentation: https://kubernetes.io/docs/
- Minikube: https://minikube.sigs.k8s.io/
- PostgreSQL: https://www.postgresql.org/
- JDBC PostgreSQL Driver: https://jdbc.postgresql.org/

## Next Steps

1. Customize database schemas in `02-postgres-db.yaml` init script
2. Add environment-specific overrides using Kustomize
3. Implement backup strategy for PostgreSQL
4. Configure ingress for external access
5. Add monitoring and logging (ELK, Prometheus, etc.)
