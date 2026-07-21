# Minikube vs Cloud Kubernetes Configuration Guide

This document explains the differences between running the Vote-Poll application locally (Minikube) vs cloud (GCP Cloud SQL).

## Quick Comparison Matrix

| Component | Minikube (Local) | Cloud (GCP) |
|-----------|------------------|------------|
| **Database Engine** | PostgreSQL (Local Container) | Google Cloud SQL |
| **Database Hostname** | `postgres-db` (k8s DNS) | `cloudsql-proxy` or Cloud SQL IP |
| **Storage** | Local Minikube PVC | Cloud Storage / GCP Persistent Disks |
| **Networking** | Internal cluster DNS | Cloud SQL Connector/Proxy |
| **Credentials** | Kubernetes Secrets (local) | Cloud Secret Manager |
| **JDBC Connection** | `jdbc:postgresql://postgres-db:5432/` | `jdbc:postgresql://cloudsql-proxy:5432/` |
| **Network Policies** | Permissive (dev-friendly) | Strict (production-grade) |
| **Deployment Size** | Single replica, minimal resources | Multi-replica, autoscaling |
| **Cost** | Free (local) | Pay-per-use |
| **Backup Strategy** | Manual/None | Automated GCP backups |
| **High Availability** | None | HA configurations |
| **SSL/TLS** | Not enforced | Enforced |

## Configuration Files Comparison

### Namespace & Base Configuration

**Both use the same:**
```yaml
# 00-namespace.yaml
# 01-configmap.yaml (with environment-specific values)
```

**Differences in ConfigMap:**

**Minikube (k8s-minikube/01-configmap.yaml):**
```yaml
DB_HOST: "postgres-db"
DB_PORT: "5432"
AUTH_DB_NAME: "auth_db"
```

**Cloud (k8s/01-configmap.yaml):**
```yaml
IMAGE_REGISTRY: "us-central1-docker.pkg.dev/PROJECT_ID/vote-poll-images"
# Uses Cloud SQL through proxy
```

### Database Configuration

#### Minikube: `02-postgres-db.yaml`

Local PostgreSQL Deployment with:
- **Image:** `postgres:15-alpine` (pulled from DockerHub)
- **Storage:** 5Gi local PVC
- **Networking:** Internal k8s ClusterIP service
- **Init Script:** Automatic database creation via ConfigMap
- **Credentials:** Stored in Kubernetes Secrets

```yaml
# Connection from services
JDBC_URL: "jdbc:postgresql://postgres-db:5432/auth_db"
```

#### Cloud: External Cloud SQL

Uses Google Cloud SQL with:
- **Proxy Connection:** Via Cloud SQL Auth Proxy pod
- **Storage:** GCP managed persistence
- **Networking:** Private VPC connection
- **Credentials:** Google Cloud Service Account + Cloud Secret Manager
- **Init Script:** Managed through Cloud SQL console or migration tools

```yaml
# Connection from services (through proxy)
JDBC_URL: "jdbc:postgresql://cloudsql-proxy:5432/auth_db"
```

### Secrets Configuration

#### Minikube (`k8s-minikube/02-secrets.yaml`)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vote-poll-secrets
  namespace: vote-poll
stringData:
  DB_USER: "postgres"
  DB_PASSWORD: "postgres_password"
  JDBC_URL: "jdbc:postgresql://postgres-db:5432/auth_db"
  JWT_SECRET: "dev-secret-key-change-in-production-12345"
```

**Issues (for dev only):**
- Plain text secrets
- Checked into git (NO! Use .gitignore in production)
- Single user/password
- Default weak JWT secret

#### Cloud (Recommended)

```bash
# Use Google Cloud Secret Manager
gcloud secrets create db-password --data-file=-
gcloud secrets create jwt-secret --data-file=-

# Reference in k8s deployments
apiVersion: v1
kind: Secret
metadata:
  name: vote-poll-secrets
type: Opaque
data:
  DB_PASSWORD: <base64 from GSM>
  JDBC_URL: <base64 jdbc url>
  JWT_SECRET: <base64 strong secret>
```

**Advantages:**
- Encrypted at rest
- Access logging
- Rotation support
- Multi-user authentication
- Strong secrets generation

### Microservice Deployments

#### Minikube Configuration

**File:** `k8s-minikube/11-auth-service.yaml` (example)

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: vote-poll-secrets
        key: JDBC_URL
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 384Mi
replicas: 1
imagePullPolicy: IfNotPresent
```

**Characteristics:**
- Single replica
- Minimal resource requests
- Local image pull
- Startup delays: 30-40 seconds
- Development-friendly health checks

#### Cloud Configuration

**File:** `k8s/11-auth-service.yaml` (expected)

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: vote-poll-secrets
        key: CLOUD_SQL_JDBC_URL
  - name: CLOUD_SQL_INSTANCE
    value: "project:region:instance"
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
replicas: 3
imagePullPolicy: IfNotPresent
```

**Characteristics:**
- Multiple replicas for HA
- Higher resource requests
- Registry image pull
- Cloud SQL Proxy sidecar
- Stricter health checks
- HPA (Horizontal Pod Autoscaler)

### Network Policies

#### Minikube (`k8s-minikube/22-network-policies.yaml`)

**Permissive for development:**
```yaml
# Allow frontend from ANY pod in namespace
- from:
    - podSelector: {}  # Allow all
```

**Rationale:**
- Easier debugging
- No IP restrictions
- Faster development iteration

#### Cloud (`k8s/22-network-policies.yaml`)

**Strict for production:**
```yaml
# Allow frontend only from specific IPs
- from:
    - ipBlock:
        cidr: 10.0.0.0/8
```

**Rationale:**
- Security hardening
- Compliance requirements
- Restrict external traffic

## Deployment Process

### Minikube Deployment Steps

```bash
# 1. Start Minikube
minikube start --cpus=4 --memory=4096

# 2. Enable storage
minikube addons enable storage-provisioner

# 3. Build and load images
docker build -t auth-service:latest ./auth-service
minikube image load auth-service:latest

# 4. Deploy all manifests
kubectl apply -f ms/k8s-minikube/

# 5. Wait for PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgres-db -n vote-poll --timeout=300s

# 6. Access services
kubectl port-forward -n vote-poll svc/api-gateway 8080:8080
kubectl port-forward -n vote-poll svc/postgres-db 5432:5432
```

### Cloud Deployment Steps

```bash
# 1. Create GKE cluster
gcloud container clusters create vote-poll --zone=us-central1-a

# 2. Create Cloud SQL instance
gcloud sql instances create vote-poll-db --database-version=POSTGRES_15

# 3. Create databases and users
gcloud sql connect vote-poll-db -- -U postgres -c "CREATE DATABASE auth_db;"

# 4. Create secrets in Cloud Secret Manager
gcloud secrets create db-password --data-file=-

# 5. Push images to Artifact Registry
docker tag auth-service:latest us-central1-docker.pkg.dev/PROJECT/auth-service:latest
docker push us-central1-docker.pkg.dev/PROJECT/auth-service:latest

# 6. Deploy with Kustomize
kubectl apply -k ms/k8s/

# 7. Create Cloud SQL Proxy
kubectl apply -f cloudsql-proxy-deployment.yaml

# 8. Configure Ingress
kubectl apply -f ingress.yaml
```

## Key Differences in Practice

### 1. Database Initialization

**Minikube:**
```yaml
# 02-postgres-db.yaml
volumeMounts:
  - name: postgres-initdb
    mountPath: /docker-entrypoint-initdb.d
volumes:
  - name: postgres-initdb
    configMap:
      name: postgres-initdb-config
```
- Automatic schema creation via init script

**Cloud:**
- Manual SQL migrations via Cloud SQL console
- Or Liquibase/Flyway in application startup

### 2. Connection Pooling

**Minikube:**
- Simple connection strings
- No proxy overhead
- Direct pod-to-pod

**Cloud:**
- Cloud SQL Proxy handles auth
- Connection pooling configured
- Network encryption

### 3. Debugging

**Minikube:**
```bash
# Direct database access
kubectl port-forward svc/postgres-db 5432:5432
psql -h localhost -U postgres
```

**Cloud:**
```bash
# Via Cloud SQL Proxy
gcloud sql connect instance-name
# Or use Cloud Console
```

### 4. Scaling

**Minikube:**
- Single PostgreSQL instance
- Manual scaling not realistic
- Good for local testing only

**Cloud:**
- Replicas for HA/read scaling
- Automated backups
- Point-in-time recovery

## Migration from Minikube to Cloud

1. **Export local data:**
   ```bash
   kubectl exec -it postgres-db-0 -- pg_dump -U postgres auth_db > auth_db_backup.sql
   ```

2. **Create Cloud SQL databases and restore:**
   ```bash
   gcloud sql connect instance-name -- -U postgres < auth_db_backup.sql
   ```

3. **Update JDBC URLs** in secrets/configmaps

4. **Deploy to Cloud Kubernetes:**
   ```bash
   kubectl apply -f ms/k8s/
   ```

5. **Verify connectivity** through Cloud SQL Proxy

## Security Considerations

### Minikube (Development Only)

❌ Do NOT use in production:
- Secrets in plaintext
- No SSL/TLS enforcement
- Single database instance
- No audit logging
- Weak default passwords

✅ Acceptable for development:
- Faster iteration
- Easy debugging
- Cost-free
- Self-contained

### Cloud (Production Ready)

✅ Security features:
- Encrypted secrets (Cloud Secret Manager)
- SSL/TLS required connections
- Cloud SQL HA with automated backups
- Audit logging and monitoring
- Fine-grained IAM controls
- VPC isolation
- Private IP connections

## Summary

| Use Case | Recommendation |
|----------|-----------------|
| **Local Development** | Use Minikube with embedded PostgreSQL |
| **Testing CI/CD Pipeline** | Use Minikube manifests for fast iteration |
| **Staging/Production** | Use Cloud configuration with Cloud SQL |
| **Multi-region Deployment** | Use Cloud with Cloud SQL HA replicas |

The files provided allow seamless switching between local and cloud environments by using environment-specific Kubernetes manifests.
