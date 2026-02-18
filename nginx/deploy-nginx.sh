#!/bin/bash
set -e

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
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true"

# Wait for LoadBalancer
echo "Waiting for LoadBalancer..."
sleep 60

# Get NLB DNS and ARN
NLB_DNS=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
NLB_ARN=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='$NLB_DNS'].LoadBalancerArn" --output text)

echo "NLB DNS: $NLB_DNS"
echo "NLB ARN: $NLB_ARN"

# Save for Terraform
cat > ../waf_cdn/terraform.tfvars << EOF
dns_record_for_nlb = "lb.savegb.org"
nlb_arn      = "$NLB_ARN"
domain_name  = "savegb.org"
EOF




if ! kubectl get ns cert-manager >/dev/null 2>&1; then
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.yaml
  kubectl wait --for=condition=available deployment/cert-manager \
    -n cert-manager --timeout=180s
fi

# Apply issuer + ingress
kubectl apply -f letsencrypt-issuer.yaml
kubectl apply -f ingress.yaml