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


helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing"


# Wait for LoadBalancer
echo "Waiting for LoadBalancer..."
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  svc/nginx-ingress-ingress-nginx-controller \
  -n ingress-nginx --timeout=180s || true

NGINX_LB=$(kubectl get svc nginx-ingress-ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "LoadBalancer: $NGINX_LB"

# ---- GREEN DOMAIN PROMPT ----
echo -e "\033[1;32mEnter your domain (e.g. savegb.org):\033[0m"
read DOMAIN

echo "Point these DNS records to: $NGINX_LB"
echo "  @ -> $NGINX_LB"
echo "  cms -> $NGINX_LB"
echo "  apps -> $NGINX_LB"

# Install cert-manager (if not exists)
if ! kubectl get ns cert-manager >/dev/null 2>&1; then
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.yaml
  kubectl wait --for=condition=available deployment/cert-manager \
    -n cert-manager --timeout=180s
fi

# Apply issuer + ingress
kubectl apply -f letsencrypt-issuer.yaml
kubectl apply -f ingress.yaml

echo "Deployment triggered."
echo "Once DNS propagates, access:"
echo "  https://$DOMAIN"
echo "  https://cms.$DOMAIN"
