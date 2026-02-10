#!/bin/bash
set -e

# Path to .env 
ENV_FILE="../.env"

# Load environment variables from .env file
echo ">>> Loading environment variables from $ENV_FILE..."
if [ -f "$ENV_FILE" ]; then
    set -a  # automatically export all variables
    source "$ENV_FILE"
    set +a  # disable auto-export
    echo "Environment variables loaded successfully"
else
    echo "ERROR: $ENV_FILE not found!"
    exit 1
fi

aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Optional: verify variables are loaded
echo ">>> Verifying key variables..."
echo "CLUSTER_NAME: $CLUSTER_NAME"
echo "AWS_REGION: $AWS_REGION"



echo "Deploy OpenedX  with Nginx Ingress + SSL "

kubectl apply -f namespace.yaml

# Step 2: Install Nginx Ingress Controller
echo -e "Step 2: Installing Nginx Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

# Check if already installed
if helm list -n ingress-nginx | grep -q nginx-ingress; then
  echo -e " Nginx Ingress already installed"
else
# Install with internet-facing annotation
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true"
  echo -e " Nginx Ingress installed"
fi


# Step 3: Wait for LoadBalancer
echo -e "Step 3: Waiting for LoadBalancer to be ready..."
echo "This may take 2-3 minutes..."
sleep 60

NGINX_LB=""
for i in {1..10}; do
  NGINX_LB=$(kubectl get svc nginx-ingress-ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null )
  
  if [ -z "$NGINX_LB" ]; then
    NGINX_LB=$(kubectl get svc nginx-ingress-ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null )
  fi
  
  if [ ! -z "$NGINX_LB" ]; then
    break
  fi
  
  echo "Waiting... ($i/10)"
  sleep 15
done

if [ -z "$NGINX_LB" ]; then
  echo -e " LoadBalancer not ready yet"
  echo "Please wait a few more minutes and check:"
  echo "  kubectl get svc -n ingress-nginx"
  exit 1
fi

echo -e " LoadBalancer ready: $NGINX_LB"


# Step 4: DNS Configuration
echo -e "Step 4: DNS Configuration Required"

echo "Please add these DNS records in Namecheap:"

echo "  Type: CNAME"
echo "  Host: @"
echo "  Value: $NGINX_LB"

echo "  Type: CNAME"
echo "  Host: cms"
echo "  Value: $NGINX_LB"

echo "  Type: CNAME"
echo "  Host: apps"
echo "  Value: $NGINX_LB"

echo -e "Press Enter after you've added the DNS records..."
read

echo "Testing DNS resolution..."


# Test LMS DNS
if nslookup savegb.org > /dev/null 2>&1; then
  echo -e " savegb.org resolves"
else
  echo -e "savegb.org not resolving yet (may take 5-30 minutes)"
fi

# Test CMS DNS
if nslookup cms.savegb.org > /dev/null 2>&1; then
  echo -e " cms.savegb.org resolves"
else
  echo -e "cms.savegb.org not resolving yet (may take 5-30 minutes)"
fi


# Step 5: Install cert-manager
echo -e "Step 5: Installing cert-manager for SSL..."

if kubectl get namespace cert-manager > /dev/null 2>&1; then
  echo -e " cert-manager already installed"
else
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.yaml
  
  echo "Waiting for cert-manager to be ready..."
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
  
  echo -e " cert-manager installed"
fi


# Step 6: Create Let's Encrypt issuer
echo -e "Step 6: Creating Let's Encrypt certificate issuer..."
kubectl apply -f letsencrypt-issuer.yaml
echo -e " Certificate issuer created"




# Step 9: Deploy ingress with SSL
echo -e "Step 9: Deploying ingress with SSL..."
kubectl apply -f openedx-ingress-ssl.yaml
echo -e " Ingress deployed"


# Step 10: Wait for certificates
echo -e "Step 10: Waiting for SSL certificates (2-3 minutes)..."
echo "This may take a while as Let's Encrypt validates your domain..."
sleep 60

for i in {1..12}; do
  LMS_CERT=$(kubectl get certificate lms-tls -n openedx -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null )
  CMS_CERT=$(kubectl get certificate cms-tls -n openedx -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null  )
  
  if [ "$LMS_CERT" == "True" ] && [ "$CMS_CERT" == "True" ]; then
    echo -e " SSL certificates issued!"
    break
  fi
  
  echo "Waiting for certificates... ($i/12)"
  sleep 15
done




echo "Your Open edX platform is now accessible at:"

echo -e "  LMS:    https://savegb.org"
echo -e "  cms: https://cms.savegb.org"

echo "Please allow a few minutes for everything to stabilize."



######################## deploy-openedx #############################

# Install Python venv if not present
echo ">>> Installing Python venv..."
if ! dpkg -l | grep -q python3.12-venv; then
    sudo apt-get update
    sudo apt-get install -y python3.12-venv
fi

# Create and activate virtual environment
echo ">>> Setting up Python virtual environment..."
python3 -m venv ~/tutor-venv
source ~/tutor-venv/bin/activate

# # Install Tutor
echo ">>> Installing Tutor..."
pip install --upgrade pip
pip install "tutor[full]"



# Configure Tutor for Kubernetes deployment
echo ">>> Configuring Tutor for Kubernetes deployment..."
rm -rf  $(tutor config printroot)


tutor config save \
  --set K8S_NAMESPACE=openedx \
  --set RUN_MYSQL=false \
  --set RUN_REDIS=false \
  --set RUN_ELASTICSEARCH=false \
  --set RUN_MONGODB=false \
  --set K8S_STORAGECLASS=gp2 \
  --set MYSQL_HOST="$MYSQL_HOST" \
  --set MYSQL_PORT="$MYSQL_PORT" \
  --set MYSQL_DATABASE="$MYSQL_DATABASE" \
  --set MYSQL_ROOT_USERNAME="$MYSQL_USERNAME" \
  --set MYSQL_ROOT_PASSWORD="$MYSQL_PASSWORD" \
  --set MYSQL_USERNAME="$MYSQL_USERNAME" \
  --set MYSQL_PASSWORD="$MYSQL_PASSWORD" \
  --set REDIS_HOST="$REDIS_HOST" \
  --set REDIS_PORT="$REDIS_PORT" \
  --set ELASTICSEARCH_HOST="$ELASTICSEARCH_HOST" \
  --set ELASTICSEARCH_PORT=443 \
  --set ELASTICSEARCH_SCHEME=https \
  --set MONGODB_HOST="$MONGODB_HOST" \
  --set MONGODB_PORT="$MONGODB_PORT" \
  --set MONGODB_USERNAME="$MONGODB_USERNAME" \
  --set MONGODB_PASSWORD="$MONGODB_PASSWORD" \
  --set MONGODB_AUTH_SOURCE=admin \
  --set MONGO_AUTH_DB=admin \
  --set OPENEDX_AWS_STORAGE_BUCKET_NAME="$S3_BUCKET" \
  --set OPENEDX_AWS_S3_REGION_NAME="$AWS_REGION" \
  --set LMS_HOST="savegb.org" \
  --set CMS_HOST="cms.savegb.org" \
  --set ENABLE_HTTPS=true





tutor k8s start

kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl delete svc caddy -n openedx
kubectl delete deploy caddy -n openedx

tutor k8s init





