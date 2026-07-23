# 🚀 Minikube Kubernetes Setup with PostgreSQL

This guide explains how to run the Vote-Poll microservices application locally using Minikube with a self-hosted PostgreSQL database, instead of Cloud SQL used in production.

## 📋 Overview

The repository contains two sets of Kubernetes configurations:

- **`ms/k8s/`** - Production configuration for Google Cloud Platform (Cloud SQL)
- **`ms/k8s-minikube/`** - Development configuration for local Minikube (PostgreSQL in container)

This document focuses on the **Minikube setup** for local development.

---

## 🎯 Key Components

### Minikube PostgreSQL Setup

```
┌─────────────────────────────────────────────────────────────┐
│                    Minikube Cluster                         │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │        vote-poll Namespace                           │  │
│  │                                                       │  │
│  │  ┌─────────────┐      ┌─────────────────────────┐  │  │
│  │  │ PostgreSQL  │      │  Microservices          │  │  │
│  │  │  Pod        │◄─────┤  - Auth Service         │  │  │
│  │  │             │      │  - User Service         │  │  │
│  │  │ Databases:  │      │  - Poll Service         │  │  │
│  │  │ ├─ auth_db  │      │  - Vote Service         │  │  │
│  │  │ ├─ user_db  │      │  - Result Service       │  │  │
│  │  │ ├─ poll_db  │      │  - API Gateway          │  │  │
│  │  │ ├─ vote_db  │      │  - Frontend             │  │  │
│  │  │ └─result_db │      └─────────────────────────┘  │  │
│  │  │             │                                     │  │
│  │  │ Service:    │                                     │  │
│  │  │ postgres-db │                                     │  │
│  │  │ :5432       │                                     │  │
│  │  └─────────────┘                                     │  │
│  │      ▲                                               │  │
│  │      │ PVC: 5Gi                                      │  │
│  │      ▼                                               │  │
│  │  ┌──────────────┐                                    │  │
│  │  │ Persistent   │                                    │  │
│  │  │ Volume       │                                    │  │
│  │  └──────────────┘                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Files Created

### 1. **02-postgres-db.yaml** - Main PostgreSQL Configuration
Contains:
- PostgreSQL 15 Alpine image Deployment
- Persistent Volume Claim (5Gi storage)
- ConfigMap with database initialization script
- Secret with PostgreSQL credentials
- ClusterIP Service for inter-pod communication

**Key Features:**
- ✅ Automatic database creation (auth_db, user_db, poll_db, vote_db, result_db)
- ✅ Health checks (liveness & readiness probes)
- ✅ Resource limits for development
- ✅ Persistent data storage

### 2. **02-secrets.yaml** - Database Credentials
Contains:
- PostgreSQL user: `postgres`
- PostgreSQL password: `postgres_password`
- JDBC URLs for each microservice
- JWT secret for authentication

```yaml
DB_USER: "postgres"
DB_PASSWORD: "postgres_password"
JDBC_URL: "jdbc:postgresql://postgres-db:5432/auth_db"
```

### 3. **01-configmap.yaml** - Updated Configuration
Enhanced with:
- Database host configuration (`DB_HOST: postgres-db`)
- Database port (`DB_PORT: 5432`)
- Individual database names for each service

### 4. **README-MINIKUBE.md** - Complete Setup Guide
Comprehensive documentation including:
- Prerequisites and installation
- Step-by-step deployment
- Database access instructions
- Troubleshooting guide

### 5. **CONFIG-COMPARISON.md** - Environment Comparison
Detailed comparison showing:
- Minikube vs Cloud differences
- Migration path to Cloud SQL
- Security considerations for each environment

---

## 🚀 Quick Start

### Step 1: Manage Minikube

```bash
# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=4096

# Verify the Cluster
kubectl get nodes
kubectl get pods -A

# Enable Useful Add-ons
minikube addons enable ingress
minikube addons enable metrics-server

# Open the Kubernetes Dashboard (Optional)
minikube dashboard

# Check the current status
minikube status

# Stop the cluster (keeps data)
minikube stop

# Restart the cluster
minikube stop
minikube start

#Delete the cluster
minikube delete

# Enable storage provisioner for persistent volumes
minikube addons enable storage-provisioner
```

### Step 2: Build Docker Images

```bash
# Build each microservice image
cd ./auth-service && docker build -t auth-service:latest .
cd ../user-service && docker build -t user-service:latest .
cd ../poll-service && docker build -t poll-service:latest .
cd ../vote-service && docker build -t vote-service:latest .
cd ../result-service && docker build -t result-service:latest .
cd ../api-gateway && docker build -t api-gateway:latest .
cd ../frontend && docker build -t frontend-service:latest .

# Load images into Minikube
minikube image load auth-service:latest
minikube image load user-service:latest
minikube image load poll-service:latest
minikube image load vote-service:latest
minikube image load result-service:latest
minikube image load api-gateway:latest
minikube image load frontend-service:latest
```

### Step 3: Deploy to Minikube

```bash
# Deploy all Kubernetes manifests
kubectl apply -f ms/k8s-minikube/

# Wait for PostgreSQL to be ready (important!)
kubectl wait --for=condition=ready pod -l app=postgres-db \
  -n vote-poll --timeout=300s

# Verify all pods are running
kubectl get pods -n vote-poll
```

### Step 4: Access Services

```bash
# Access PostgreSQL
kubectl port-forward -n vote-poll svc/postgres-db 5432:5432
psql -h localhost -U postgres

# Access API Gateway
kubectl port-forward -n vote-poll svc/api-gateway 8080:8080
curl http://localhost:8080/api/health

# Access Frontend
kubectl port-forward -n vote-poll svc/frontend-service 3000:3000
open http://localhost:3000
```

---

## 🗄️ Database Configuration

### Connection Details

| Property | Value |
|----------|-------|
| Host | `postgres-db` (internal), `localhost` (port-forwarded) |
| Port | 5432 |
| Username | postgres |
| Password | postgres_password |
| Storage | 5Gi PVC |

### Databases & Services

| Database | Service | Purpose |
|----------|---------|---------|
| auth_db | Auth Service | User authentication and JWT tokens |
| user_db | User Service | User profiles and personal data |
| poll_db | Poll Service | Poll creation and management |
| vote_db | Vote Service | Vote records and calculations |
| result_db | Result Service | Vote aggregation and results |

### JDBC Connection URLs

Each microservice connects using:

```
jdbc:postgresql://postgres-db:5432/{database_name}
```

Examples:
```
jdbc:postgresql://postgres-db:5432/auth_db
jdbc:postgresql://postgres-db:5432/user_db
jdbc:postgresql://postgres-db:5432/poll_db
jdbc:postgresql://postgres-db:5432/vote_db
jdbc:postgresql://postgres-db:5432/result_db
```

---

## 📊 Minikube vs Production (Cloud SQL)

| Feature | Minikube | Cloud SQL |
|---------|----------|-----------|
| **Database Engine** | PostgreSQL 15 (Container) | Google Cloud SQL |
| **Storage** | Local Minikube PVC | GCP Cloud Storage |
| **Network** | k8s ClusterIP (postgres-db) | Cloud SQL Proxy |
| **Credentials** | k8s Secrets | Cloud Secret Manager |
| **Replicas** | 1 (single instance) | 3+ (HA) |
| **Backups** | None (manual if needed) | Automatic daily |
| **SSL/TLS** | Not enforced | Required |
| **High Availability** | ❌ No | ✅ Yes |
| **Scaling** | Manual | Auto-scaling |
| **Cost** | Free | Pay-per-use |
| **Best For** | Local development | Production workloads |

---

## 🔧 Configuration Files Breakdown

### 02-postgres-db.yaml Structure

```yaml
# 1. ConfigMap: postgres-initdb-config
#    └─ Contains init.sql with CREATE DATABASE and table schemas

# 2. Secret: postgres-secret  
#    └─ POSTGRES_USER, POSTGRES_PASSWORD

# 3. PersistentVolumeClaim: postgres-pvc
#    └─ 5Gi storage, storageClassName: standard

# 4. Deployment: postgres-db
#    ├─ Image: postgres:15-alpine
#    ├─ Ports: 5432
#    ├─ VolumeMounts: 
#    │  ├─ /var/lib/postgresql/data (PVC)
#    │  └─ /docker-entrypoint-initdb.d (ConfigMap)
#    ├─ Resources: 100m CPU, 256Mi memory (request)
#    └─ Probes: liveness & readiness checks

# 5. Service: postgres-db
#    └─ ClusterIP on port 5432
```

### Initialization Script (init.sql)

The ConfigMap includes an init.sql that:
1. ✅ Creates 5 databases
2. ✅ Creates tables for each service
3. ✅ Sets up relationships and constraints
4. ✅ Runs automatically on container startup

---

## 🐛 Troubleshooting

### PostgreSQL Pod Won't Start

```bash
# Check pod status and events
kubectl describe pod -n vote-poll -l app=postgres-db

# Check logs
kubectl logs -n vote-poll -l app=postgres-db

# Check PVC
kubectl get pvc -n vote-poll
kubectl describe pvc postgres-pvc -n vote-poll
```

### Cannot Connect to Database

```bash
# Test DNS resolution
kubectl exec -it <pod-name> -n vote-poll -- nslookup postgres-db

# Test connectivity
kubectl exec -it <pod-name> -n vote-poll -- nc -zv postgres-db 5432

# Check service endpoints
kubectl get endpoints -n vote-poll postgres-db
```

### Microservice Connection Issues

```bash
# Verify secrets exist
kubectl get secrets -n vote-poll
kubectl describe secret vote-poll-secrets -n vote-poll

# Check environment variables
kubectl exec -it <pod-name> -n vote-poll -- env | grep DATABASE

# View microservice logs
kubectl logs -n vote-poll -l app=auth-service
```

---

## 🔄 Workflow: Local Development

### 1. Make code changes
```bash
# Edit your microservice code
vim auth-service/src/main/java/...
```

### 2. Rebuild image
```bash
docker build -t auth-service:latest ./auth-service
minikube image load auth-service:latest
```

### 3. Redeploy
```bash
# Delete old pod (new one will be created with new image)
kubectl delete pod -n vote-poll -l app=auth-service

# Or update the deployment timestamp
kubectl patch deployment auth-service -n vote-poll \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"date\":\"$(date +%s)\"}}}}"
```

### 4. Check logs
```bash
kubectl logs -n vote-poll -l app=auth-service -f
```

---

## 🚀 Deployment Checklist

- [ ] Minikube installed and started
- [ ] Storage provisioner enabled
- [ ] All Docker images built and loaded
- [ ] Namespaces created
- [ ] ConfigMap applied
- [ ] Secrets applied
- [ ] PostgreSQL Deployment running
- [ ] PostgreSQL Pod ready (wait for readiness probe)
- [ ] Microservices Deployments applied
- [ ] All Pods in Running state
- [ ] Services created and accessible
- [ ] Port forwarding working
- [ ] Database queries returning results

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `README-MINIKUBE.md` | Detailed Minikube setup and reference |
| `CONFIG-COMPARISON.md` | Minikube vs Cloud detailed comparison |
| `MINIKUBE-SETUP.md` | This file - quick reference |
| `k8s-minikube/*.yaml` | Kubernetes manifests |

---

## 🔐 Security Notes

⚠️ **FOR DEVELOPMENT ONLY** ⚠️

The setup includes hardcoded credentials suitable only for local development:
- Default PostgreSQL password
- Secrets stored in git
- No SSL/TLS enforcement
- Permissive network policies

**For Production:**
- Use Cloud Secret Manager
- Enable SSL/TLS
- Implement strict network policies
- Use Cloud SQL with automated backups
- Enable IAM-based authentication

---

## 🎯 Next Steps

1. **Customize Schemas** - Edit init.sql in 02-postgres-db.yaml for your specific requirements
2. **Add Monitoring** - Deploy Prometheus and Grafana
3. **Setup CI/CD** - Create GitHub Actions for automated testing
4. **Kustomize Overlays** - Create environment-specific configurations
5. **Backup Strategy** - Implement regular PostgreSQL backups
6. **Ingress Configuration** - Setup Minikube Ingress for external access

---

## 📞 Support

For detailed information:
- See `README-MINIKUBE.md` for complete setup guide
- See `CONFIG-COMPARISON.md` for Minikube vs Cloud details
- Check Kubernetes docs: https://kubernetes.io/docs/
- Minikube guide: https://minikube.sigs.k8s.io/

---

**Created:** 2026-07-21
**Last Updated:** 2026-07-21
