#!/bin/bash
# =============================================================================
# MongoDB 7.0 – Deploy script for openedx namespace
# Usage:  chmod +x deploy.sh && ./deploy.sh
# =============================================================================
set -euo pipefail

NAMESPACE="openedx"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
die()  { echo -e "${RED}✗ $*${NC}"; exit 1; }

echo "=========================================="
echo " MongoDB Deploy → namespace: $NAMESPACE"
echo "=========================================="

# ── Pre-flight checks ────────────────────────────────────────────────────────
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || die "Namespace $NAMESPACE not found. Run: kubectl create ns $NAMESPACE"
ok "Namespace $NAMESPACE exists"

KEYFILE_PLACEHOLDER="UkVQTEFDRV9XSVRIXzc1Nl9CWVRFX0JBU0U2NF9LRVk="
if grep -q "$KEYFILE_PLACEHOLDER" "$DIR/01-secret.yaml"; then
  die "MONGO_REPLICA_SET_KEY is still the placeholder!\nRun: openssl rand -base64 756 | base64 -w 0\nThen paste the output into 01-secret.yaml"
fi
ok "Keyfile secret looks real"

# ── Apply in order ───────────────────────────────────────────────────────────
MANIFESTS=(
  # "00-namespace.yaml"
  "01-secret.yaml"
  "02-configmap.yaml"
  "03-serviceaccount.yaml"
  "04-role.yaml"
  "05-rolebinding.yaml"
  "06-service-headless.yaml"
  "07-service-client.yaml"
  "08-service-secondary.yaml"
  "09-pdb.yaml"
  "10-storageclass.yaml"
  "11-statefulset.yaml"
  "12-networkpolicy.yaml"
)

for manifest in "${MANIFESTS[@]}"; do
  kubectl apply -f "$DIR/$manifest"
  ok "Applied $manifest"
done

# ── Wait for StatefulSet rollout ─────────────────────────────────────────────
echo ""
echo "Waiting for StatefulSet rollout (this may take 2-3 min on first run)..."
kubectl -n "$NAMESPACE" rollout status sts/mongodb --timeout=300s
ok "StatefulSet mongodb is ready"

bash ./init-db.sh

# # ── Run init job ─────────────────────────────────────────────────────────────
# echo ""
# echo "Applying init Job (rs0 init + OpenedX users)..."

# # Delete stale job if exists
# if kubectl -n "$NAMESPACE" get job mongodb-init >/dev/null 2>&1; then
#   warn "Existing mongodb-init job found – deleting before reapply"
#   kubectl -n "$NAMESPACE" delete job mongodb-init
#   sleep 2
# fi

# kubectl apply -f "$DIR/13-init-job.yaml"
# ok "Init job submitted"

# echo "Streaming init job logs (Ctrl+C to detach – job keeps running)..."
# kubectl -n "$NAMESPACE" wait --for=condition=ready pod \
#   -l job-name=mongodb-init --timeout=120s 2>/dev/null || true
# kubectl -n "$NAMESPACE" logs -f job/mongodb-init

# # ── Apply ServiceMonitor (optional – needs prometheus-operator) ──────────────
# echo ""
# if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
#   kubectl apply -f "$DIR/14-servicemonitor.yaml"
#   ok "ServiceMonitor applied"
# else
#   warn "prometheus-operator CRD not found – skipping 14-servicemonitor.yaml"
# fi

# # ── Summary ──────────────────────────────────────────────────────────────────
# echo ""
# echo "=========================================="
# echo " Deploy complete"
# echo "=========================================="
# kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/name=mongodb
# echo ""
# kubectl -n "$NAMESPACE" get pvc | grep mongodb || true
# echo ""
# echo "Connection (replica-set aware):"
# echo "  mongodb://openedx:Admin123%40@mongodb-0.mongodb-headless.openedx.svc.cluster.local:27017,mongodb-1.mongodb-headless.openedx.svc.cluster.local:27017,mongodb-2.mongodb-headless.openedx.svc.cluster.local:27017/<db>?replicaSet=rs0&authSource=<db>"
# echo "=========================================="
