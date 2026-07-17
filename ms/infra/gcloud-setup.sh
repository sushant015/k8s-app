#!/usr/bin/env bash
# Vote Polling Platform — GCP Infrastructure Setup
# Run in Google Cloud Shell. No public IPs on GKE, Cloud SQL, or frontend.

set -euo pipefail

# ── Configuration (edit these) ──────────────────────────────────────────────
export PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"
export REGION="${REGION:-us-central1}"
export ZONE="${ZONE:-us-central1-a}"
export CLUSTER_NAME="${CLUSTER_NAME:-vote-poll-cluster}"
export VPC_NAME="${VPC_NAME:-vote-poll-vpc}"
export SUBNET_NAME="${SUBNET_NAME:-vote-poll-subnet}"
export SUBNET_RANGE="${SUBNET_RANGE:-10.10.0.0/20}"
export PODS_RANGE="${PODS_RANGE:-10.20.0.0/16}"
export SERVICES_RANGE="${SERVICES_RANGE:-10.30.0.0/20}"
export SQL_INSTANCE="${SQL_INSTANCE:-vote-poll-sql}"
export DB_NAME="${DB_NAME:-votepoll}"
export DB_USER="${DB_USER:-votepoll}"
export AR_REPO="${AR_REPO:-vote-poll-images}"

echo "=== Project: $PROJECT_ID | Region: $REGION ==="

# ── 1. Enable APIs ───────────────────────────────────────────────────────────
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  servicenetworking.googleapis.com \
  artifactregistry.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project="$PROJECT_ID"

# ── 2. VPC + Subnet (private only) ───────────────────────────────────────────
gcloud compute networks create "$VPC_NAME" \
  --subnet-mode=custom \
  --project="$PROJECT_ID" || true

gcloud compute networks subnets create "$SUBNET_NAME" \
  --network="$VPC_NAME" \
  --region="$REGION" \
  --range="$SUBNET_RANGE" \
  --enable-private-ip-google-access \
  --project="$PROJECT_ID" || true

# Secondary ranges for GKE pods and services
gcloud compute networks subnets update "$SUBNET_NAME" \
  --region="$REGION" \
  --add-secondary-ranges="pods=$PODS_RANGE,services=$SERVICES_RANGE" \
  --project="$PROJECT_ID" || true

# ── 3. Cloud NAT (outbound only, no inbound public access) ───────────────────
gcloud compute routers create vote-poll-router \
  --network="$VPC_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" || true

gcloud compute routers nats create vote-poll-nat \
  --router=vote-poll-router \
  --region="$REGION" \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips \
  --project="$PROJECT_ID" || true

# ── 4. Private Service Connection for Cloud SQL ──────────────────────────────
gcloud compute addresses create google-managed-services-"$VPC_NAME" \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network="$VPC_NAME" \
  --project="$PROJECT_ID" || true

gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-"$VPC_NAME" \
  --network="$VPC_NAME" \
  --project="$PROJECT_ID" || true

# ── 5. Cloud SQL PostgreSQL (HA, private IP only) ────────────────────────────
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 24)}"

gcloud sql instances create "$SQL_INSTANCE" \
  --database-version=POSTGRES_15 \
  --tier=db-custom-2-7680 \
  --region="$REGION" \
  --availability-type=REGIONAL \
  --storage-type=SSD \
  --storage-size=20GB \
  --storage-auto-increase \
  --network="$VPC_NAME" \
  --no-assign-ip \
  --project="$PROJECT_ID" || true

gcloud sql databases create "$DB_NAME" \
  --instance="$SQL_INSTANCE" \
  --project="$PROJECT_ID" || true

gcloud sql users create "$DB_USER" \
  --instance="$SQL_INSTANCE" \
  --password="$DB_PASSWORD" \
  --project="$PROJECT_ID" || true

SQL_PRIVATE_IP=$(gcloud sql instances describe "$SQL_INSTANCE" \
  --format='value(ipAddresses[0].ipAddress)' --project="$PROJECT_ID")

echo "Cloud SQL private IP: $SQL_PRIVATE_IP"
echo "DB Password (save securely): $DB_PASSWORD"

# ── 6. Artifact Registry ─────────────────────────────────────────────────────
gcloud artifacts repositories create "$AR_REPO" \
  --repository-format=docker \
  --location="$REGION" \
  --description="Vote poll microservice images" \
  --project="$PROJECT_ID" || true

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# ── 7. Private GKE Cluster (no public node IPs) ──────────────────────────────
gcloud container clusters create "$CLUSTER_NAME" \
  --region="$REGION" \
  --network="$VPC_NAME" \
  --subnetwork="$SUBNET_NAME" \
  --enable-private-nodes \
  --enable-ip-alias \
  --cluster-secondary-range-name=pods \
  --services-secondary-range-name=services \
  --master-ipv4-cidr=172.16.0.0/28 \
  --enable-master-authorized-networks \
  --master-authorized-networks=10.0.0.0/8 \
  --num-nodes=2 \
  --min-nodes=2 \
  --max-nodes=5 \
  --enable-autoscaling \
  --enable-autorepair \
  --enable-autoupgrade \
  --workload-pool="${PROJECT_ID}.svc.id.goog" \
  --project="$PROJECT_ID" || true

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region="$REGION" --project="$PROJECT_ID"

# ── 8. Create K8s namespace and secrets ──────────────────────────────────────
kubectl create namespace vote-poll --dry-run=client -o yaml | kubectl apply -f -

JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 32)}"
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${SQL_PRIVATE_IP}:5432/${DB_NAME}"
JDBC_URL="jdbc:postgresql://${SQL_PRIVATE_IP}:5432/${DB_NAME}"

kubectl -n vote-poll create secret generic vote-poll-secrets \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --from-literal=JDBC_URL="$JDBC_URL" \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=JWT_SECRET="$JWT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 9. Initialize database schema ────────────────────────────────────────────
echo ""
echo "=== Run database init from a bastion/VPN-connected machine ==="
echo "  psql \"host=${SQL_PRIVATE_IP} dbname=${DB_NAME} user=${DB_USER}\" -f ms/database/init.sql"
echo ""
echo "=== Build and push images ==="
echo "  export PROJECT_ID=$PROJECT_ID REGION=$REGION"
echo "  ./ms/scripts/build-and-push.sh"
echo ""
echo "=== Deploy to GKE ==="
echo "  kubectl apply -f ms/k8s/"
echo ""
echo "=== Access frontend via Internal Load Balancer (from VPC/VPN only) ==="
echo "  kubectl get svc -n vote-poll frontend-service"
echo ""
echo "Setup complete."
