#!/bin/bash
set -euo pipefail

ENV_FILE="../.env"

echo ">>> Loading environment variables..."
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "ERROR: $ENV_FILE not found!"
    exit 1
fi





echo "    Role ARN: $CLUSTSER_AUTO_SCALER_ARN"

echo ""
echo "Installing Cluster Autoscaler via Helm..."
helm repo add autoscaler https://kubernetes.github.io/autoscaler 2>/dev/null || true
helm repo update

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
    --namespace kube-system \
    --set autoDiscovery.clusterName="$CLUSTER_NAME" \
    --set awsRegion="$AWS_REGION" \
    --set rbac.create=true \
    --set rbac.serviceAccount.create=true \
    --set rbac.serviceAccount.name="cluster-autoscaler" \
    --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$CLUSTSER_AUTO_SCALER_ARN" \
    --set extraArgs.balance-similar-node-groups=true \
    --set extraArgs.skip-nodes-with-system-pods=false \
    --set extraArgs.scale-down-utilization-threshold=0.5 \
    --set extraArgs.scale-down-delay-after-add=2m \
    --set extraArgs.scale-down-unneeded-time=2m \
    --wait \
    --timeout 120s


echo "Cluster Auto Scaler Deployed"

