#!/bin/bash
# Run load test using an in-cluster temporary pod.
# Designed to be gentle on low-resource local environments (e.g. 4 CPU, 4GB RAM).
echo "=========================================================="
echo "Starting load test on frontend inside the cluster..."
echo "=========================================================="

# Defaults for low-resource environments
CONCURRENCY=${1:-25}
DURATION=${2:-1m}
QPS=${3:-10}

echo "Config: Concurrency=${CONCURRENCY}, Duration=${DURATION}, Max QPS/worker=${QPS}"
echo "=========================================================="

# Run load test pod with rate-limiting to prevent crashing Minikube
kubectl run load-test --image=williamyeh/hey --rm -i --restart=Never -- \
  -z "$DURATION" \
  -c "$CONCURRENCY" \
  -q "$QPS" \
  http://frontend.vote-poll.svc:8080/
