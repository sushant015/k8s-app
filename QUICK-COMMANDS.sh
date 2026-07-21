#!/bin/bash
# Quick Commands for Minikube PostgreSQL Setup
# Run each command manually or copy-paste groups

# ============================================================================
# PHASE 1: MINIKUBE SETUP
# ============================================================================

# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=4096

# Enable storage provisioner
minikube addons enable storage-provisioner

# Verify Minikube is running
minikube status


# ============================================================================
# PHASE 2: BUILD DOCKER IMAGES
# ============================================================================

# Build auth service
docker build -t auth-service:latest ./auth-service
minikube image load auth-service:latest

# Build user service
docker build -t user-service:latest ./user-service
minikube image load user-service:latest

# Build poll service
docker build -t poll-service:latest ./poll-service
minikube image load poll-service:latest

# Build vote service
docker build -t vote-service:latest ./vote-service
minikube image load vote-service:latest

# Build result service
docker build -t result-service:latest ./result-service
minikube image load result-service:latest

# Build api gateway
docker build -t api-gateway:latest ./api-gateway
minikube image load api-gateway:latest

# Build frontend
docker build -t frontend-service:latest ./frontend
minikube image load frontend-service:latest

# Verify images are loaded in Minikube
minikube image ls | grep service


# ============================================================================
# PHASE 3: DEPLOY KUBERNETES MANIFESTS
# ============================================================================

# Deploy all manifests
kubectl apply -f ms/k8s-minikube/

# Wait for PostgreSQL to be ready (IMPORTANT!)
kubectl wait --for=condition=ready pod -l app=postgres-db \
  -n vote-poll --timeout=300s

# Verify deployment
kubectl get pods -n vote-poll
kubectl get svc -n vote-poll


# ============================================================================
# PHASE 4: VERIFICATION
# ============================================================================

# Check all pods are running
kubectl get pods -n vote-poll

# Check all services
kubectl get svc -n vote-poll

# Check PostgreSQL logs
kubectl logs -n vote-poll -l app=postgres-db

# Check specific pod status
kubectl describe pod -n vote-poll -l app=postgres-db

# Check persistent volume claims
kubectl get pvc -n vote-poll


# ============================================================================
# PHASE 5: LOCAL ACCESS (Run each in separate terminal)
# ============================================================================

# Terminal 1: PostgreSQL access
kubectl port-forward -n vote-poll svc/postgres-db 5432:5432

# Terminal 2: API Gateway access
kubectl port-forward -n vote-poll svc/api-gateway 8080:8080

# Terminal 3: Frontend access
kubectl port-forward -n vote-poll svc/frontend-service 3000:3000


# ============================================================================
# PHASE 6: TESTING DATABASE
# ============================================================================

# Test PostgreSQL connection
psql -h localhost -U postgres -c "SELECT 1;"

# List databases
psql -h localhost -U postgres -l

# List tables in auth_db
psql -h localhost -U postgres -d auth_db -c "\dt"

# Insert test data
psql -h localhost -U postgres -d auth_db << EOF
INSERT INTO users (username, email, password_hash)
VALUES ('testuser', 'test@example.com', 'hashed_password');
SELECT * FROM users;
EOF

# Test other databases
psql -h localhost -U postgres -d user_db -c "SELECT 1;"
psql -h localhost -U postgres -d poll_db -c "SELECT 1;"
psql -h localhost -U postgres -d vote_db -c "SELECT 1;"
psql -h localhost -U postgres -d result_db -c "SELECT 1;"


# ============================================================================
# PHASE 7: TEST MICROSERVICES
# ============================================================================

# Test API Gateway health
curl http://localhost:8080/api/health

# Test Auth Service health
curl http://localhost:8080/api/auth/health

# Test User Service health
curl http://localhost:8080/api/user/health

# Test Poll Service health
curl http://localhost:8080/api/poll/health

# Test Vote Service health
curl http://localhost:8080/api/vote/health

# Test Result Service health
curl http://localhost:8080/api/result/health


# ============================================================================
# PHASE 8: VIEW LOGS
# ============================================================================

# View PostgreSQL logs
kubectl logs -n vote-poll -l app=postgres-db -f

# View Auth Service logs
kubectl logs -n vote-poll -l app=auth-service -f

# View API Gateway logs
kubectl logs -n vote-poll -l app=api-gateway -f

# View all pod logs (follow)
kubectl logs -n vote-poll --all-containers=true -f


# ============================================================================
# DEBUGGING COMMANDS
# ============================================================================

# Check environment variables in a pod
kubectl exec -it <pod-name> -n vote-poll -- env | grep DATABASE

# Test DNS resolution from a pod
kubectl exec -it <pod-name> -n vote-poll -- nslookup postgres-db

# Test database connectivity from a pod
kubectl exec -it <pod-name> -n vote-poll -- nc -zv postgres-db 5432

# Enter a pod's shell
kubectl exec -it <pod-name> -n vote-poll -- /bin/bash

# Check secret contents (base64 encoded)
kubectl get secret vote-poll-secrets -n vote-poll -o yaml

# Decode a secret value
kubectl get secret vote-poll-secrets -n vote-poll -o jsonpath='{.data.DB_PASSWORD}' | base64 -d


# ============================================================================
# MAINTENANCE COMMANDS
# ============================================================================

# Scale a deployment
kubectl scale deployment auth-service -n vote-poll --replicas=2

# Restart a pod
kubectl delete pod -n vote-poll -l app=auth-service

# View pod events
kubectl get events -n vote-poll --sort-by='.lastTimestamp'

# Describe a deployment
kubectl describe deployment auth-service -n vote-poll

# Delete a pod to trigger recreation
kubectl delete pod -n vote-poll postgres-db-xxx (replace xxx)


# ============================================================================
# CLEANUP
# ============================================================================

# Delete all resources in the namespace
kubectl delete namespace vote-poll

# Stop Minikube
minikube stop

# Fully remove Minikube (WARNING: This deletes all data)
minikube delete


# ============================================================================
# ONE-LINER DEPLOYMENT
# ============================================================================

# Complete deployment in one command (after images are built)
kubectl apply -f ms/k8s-minikube/ && \
kubectl wait --for=condition=ready pod -l app=postgres-db -n vote-poll --timeout=300s && \
kubectl get pods -n vote-poll


# ============================================================================
# BACKUP POSTGRESQL DATA
# ============================================================================

# Dump a database
kubectl exec -it postgres-db-xxx -n vote-poll -- pg_dump -U postgres auth_db > auth_db_backup.sql

# Dump all databases
kubectl exec -it postgres-db-xxx -n vote-poll -- pg_dumpall -U postgres > all_databases_backup.sql

# Restore a database
kubectl exec -it postgres-db-xxx -n vote-poll -- psql -U postgres < auth_db_backup.sql


# ============================================================================
# USEFUL ALIASES (add to ~/.bashrc or ~/.zshrc)
# ============================================================================

# Get current context
alias k='kubectl'
alias kn='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods -n vote-poll'
alias kgs='kubectl get svc -n vote-poll'
alias kl='kubectl logs -n vote-poll'

# Quick access to vote-poll namespace
alias kprod='kubectl config set-context --current --namespace vote-poll'

# Then use: k get pods (instead of kubectl get pods)
