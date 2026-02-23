#!/bin/bash
set -euo pipefail

ENV_FILE="../.env"

# Load env
[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Namespace
kubectl apply -f namespace.yaml

# Install Nginx Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true" \
  --wait \
  --timeout 120s

# Wait for LoadBalancer IP to be assigned (poll instead of blind sleep)
echo "Waiting for LoadBalancer hostname..."
NLB_DNS=""
for i in $(seq 1 30); do
  NLB_DNS=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$NLB_DNS" ] && break
  echo "  attempt $i/30 — not ready yet, waiting 10s..."
  sleep 10
done

if [ -z "$NLB_DNS" ]; then
  echo "ERROR: Timed out waiting for NLB hostname" >&2
  exit 1
fi

NLB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$NLB_DNS'].LoadBalancerArn" \
  --output text)

if [ -z "$NLB_ARN" ]; then
  echo "ERROR: Could not resolve NLB ARN for DNS: $NLB_DNS" >&2
  exit 1
fi

echo "NLB DNS: $NLB_DNS"
echo "NLB ARN: $NLB_ARN"

# Save for Terraform
cat > ../waf_cdn/terraform.tfvars << EOF
dns_record_for_nlb = "lb.savegb.org"
nlb_arn            = "$NLB_ARN"
nlb_dns            = "$NLB_DNS"
domain_name        = "savegb.org"
EOF

