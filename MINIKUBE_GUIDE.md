# 🚀 Local Development Guide for Minikube

This guide provides comprehensive instructions for setting up, deploying, and managing the Vote-Poll microservices application on a local Minikube cluster.

## Overview

For local development, we use Minikube to simulate a Kubernetes environment. A PostgreSQL database runs inside a container within the cluster, providing a self-contained setup that is free and easy to manage.

### Architecture on Minikube

```
┌─────────────────────────────────────────────────────────────┐
│                    Minikube Cluster                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                 vote-poll Namespace                  │  │
│  │                                                       │  │
│  │  ┌─────────────┐      ┌─────────────────────────┐  │  │
│  │  │ PostgreSQL  │      │  Microservices          │  │  │
│  │  │  Pod        │◄─────┤  - Frontend             │  │  │
│  │  │ (postgres)  │      │  - API Gateway          │  │  │
│  │  │             │      │  - Auth, User, Poll,    │  │  │
│  │  │ Service:    │      │    Vote, Result Services  │  │  │
│  │  │ postgres-db │      └─────────────────────────┘  │  │
│  │  └─────────────┘                                     │  │
│  │      ▲                                               │  │
│  │      │ PVC (Data persists across restarts)           │  │
│  │      ▼                                               │  │
│  │  ┌──────────────┐                                    │  │
│  │  │ Persistent   │                                    │  │
│  │  │ Volume       │                                    │  │
│  │  └──────────────┘                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Phase 1: Initial Setup (One-Time)

First, prepare your local machine and Minikube cluster.

### 1. Install Prerequisites
- **Docker Desktop:** [Install Guide](https://docs.docker.com/get-docker/)
- **Minikube:** [Install Guide](https://minikube.sigs.k8s.io/docs/start/)
- **kubectl:** [Install Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### 2. Start and Configure Minikube

Start Minikube with sufficient resources and enable necessary addons.

```bash
# Start the Minikube cluster
minikube start --cpus=4 --memory=4096

# Enable the storage provisioner for Persistent Volumes
minikube addons enable storage-provisioner

# (Optional) Enable the Ingress controller
minikube addons enable ingress

# Verify the cluster is running
minikube status
kubectl get nodes
```

---

## 🚀 Phase 2: Deploy the Application

The recommended way to deploy is using our all-in-one script. It handles building, loading, and deploying everything for you.

### Full Rebuild and Deploy

This is the main command you will use. It rebuilds all microservice images and deploys them to your Minikube cluster.

```bash
# Navigate to the project root
cd /path/to/k8s-app

# Make the script executable (only needs to be done once)
chmod +x ms/scripts/rebuild-all-minikube.sh

# Run the script
./ms/scripts/rebuild-all-minikube.sh
```

**What does this script do?**
1.  **Validates** your environment.
2.  **Cleans** old Docker images.
3.  **Builds** fresh images for all services with a unique tag.
4.  **Loads** these images into your Minikube cluster.
5.  **Deploys** all Kubernetes manifests from `ms/k8s-minikube/`, triggering a rolling update of all services.

---

## 🔎 Phase 3: Access and Verify

Once the script finishes, your application is running. Use `port-forward` to access the services from your local machine. **Run each command in a separate terminal.**

### 1. Access the Frontend

```bash
# Terminal 1: Forward the frontend service
kubectl port-forward -n vote-poll svc/frontend 3000:8080
```
> 🌍 Open your browser to **http://localhost:3000**

### 2. Access the API Gateway (for direct API testing)

```bash
# Terminal 2: Forward the API gateway
kubectl port-forward -n vote-poll svc/api-gateway 8080:8080
```
> ⚙️ Test the health endpoint: `curl http://localhost:8080/api/health`

### 3. Access the PostgreSQL Database

```bash
# Terminal 3: Forward the PostgreSQL service
kubectl port-forward -n vote-poll svc/postgres-db 5432:5432
```
> 🐘 Connect with a SQL client at `localhost:5432` (User: `postgres`, Pass: `postgres_password`).

---

## 🔄 Daily Development Workflow

Your daily workflow will typically involve these steps:

1.  **Make Code Changes:** Edit the source code of one or more microservices.

2.  **Re-run the Deploy Script:**
    ```bash
    ./ms/scripts/rebuild-all-minikube.sh
    ```
    The script is smart enough to only rebuild what's necessary and will perform a rolling update of your services in Kubernetes with zero downtime.

3.  **Verify Changes:** Refresh your browser at `http://localhost:3000` to see your changes.

> **⚡ Pro Tip for Faster Iteration:**
> If you are only working on a single service, you can use the `rebuild-single-minikube.sh` script to build and deploy just that one service, which is much faster than rebuilding everything.
> ```bash
> # Example: Rebuild only the poll-service
> ./ms/scripts/rebuild-single-minikube.sh poll-service
> ```


---

## 🐛 Troubleshooting and Useful Commands

### Viewing Logs

```bash
# Follow logs for a specific service (e.g., poll-service)
kubectl logs -n vote-poll -l app=poll-service -f

# Follow logs for all services at once
kubectl logs -n vote-poll -f --all-containers=true
```

### Checking Pod Status

```bash
# Get a list of all running pods and their status
kubectl get pods -n vote-poll

# Get detailed information about a specific pod (useful for errors)
kubectl describe pod <pod-name> -n vote-poll
```

### Interacting with Pods

```bash
# Open a shell inside a running container
kubectl exec -it <pod-name> -n vote-poll -- /bin/sh

# Check environment variables inside a pod
kubectl exec <pod-name> -n vote-poll -- env
```

### Database Connection Issues

If a service can't connect to the database:
1.  Ensure the PostgreSQL pod is `Running`: `kubectl get pods -n vote-poll -l app=postgres-db`
2.  Test DNS from another pod: `kubectl exec -it <app-pod-name> -n vote-poll -- nslookup postgres-db`
    - It should resolve to the internal IP of the `postgres-db` service.

---

## 🧹 Cleanup

### Stop the Application

To stop the application but keep the database data:

```bash
# Delete all resources in the namespace
kubectl delete namespace vote-poll
```

### Stop Minikube

```bash
# Stop the Minikube VM to save resources
minikube stop
```

### Full Reset (Deletes Everything)

**Warning:** This will delete your Minikube cluster and all data, including the database.

```bash
minikube delete
```

---