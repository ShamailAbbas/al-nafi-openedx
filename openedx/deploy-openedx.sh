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

echo ">>> Installing S3 plugin..."
# pip install git+https://github.com/cleura/tutor-contrib-s3@v2.5.0
# tutor plugins enable s3

# Configure Tutor for Kubernetes deployment
echo ">>> Configuring Tutor for Kubernetes deployment..."


# rm -rf  $(tutor config printroot)






tutor config save \
  --set K8S_NAMESPACE=openedx \
  --set RUN_MYSQL=false \
  --set RUN_REDIS=false \
  --set RUN_ELASTICSEARCH=false \
  --set RUN_MONGODB=false \
  --set K8S_STORAGECLASS=gp3 \
  --set LMS_HOST="savegb.org" \
  --set CMS_HOST="cms.savegb.org" \
  --set ENABLE_HTTPS=true \
  --set ENABLE_WEB_PROXY=false \
  --set MINIO_GATEWAY="s3" \
  --set OPENEDX_AWS_ACCESS_KEY="$AWS_ACCESS_KEY" \
  --set OPENEDX_AWS_SECRET_ACCESS_KEY="$AWS_SECERT_ACCESS_KEY" \
  --set S3_REGION="$AWS_REGION" \
  --set MINIO_BUCKET_NAME="$S3_STORAGE_BUCKET" \
  --set MINIO_FILE_UPLOAD_BUCKET_NAME="$S3_STORAGE_BUCKET" \
  --set MINIO_GRADES_BUCKET_NAME="$S3_STORAGE_BUCKET" \
  --set MINIO_HOST="s3.${AWS_REGION}.amazonaws.com" \
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
  --set SESSION_COOKIE_DOMAIN=savegb.org \
  --set SESSION_COOKIE_SECURE=true \
  --set CSRF_COOKIE_SECURE=true \
  --set SESSION_COOKIE_SAMESITE='Lax' \
  --set LMS_ROOT_URL=https://savegb.org \
  --set CMS_ROOT_URL=https://cms.savegb.org \
  --set RATELIMIT_ENABLE=false \
  --set REGISTRATION_RATELIMIT=1000000/minute \
  --set RATELIMIT_RATE=600/m \
  --set CSRF_TRUSTED_ORIGINS="['https://savegb.org', 'https://cms.savegb.org', 'https://apps.savegb.org']" \
  --set OPENEDX_CSRF_COOKIE_DOMAIN=.savegb.org \
  --set OPENEDX_CSRF_COOKIE_NAME=csrftoken \
  --set CORS_ALLOW_CREDENTIALS=true \
  --set CORS_ORIGIN_WHITELIST="['https://savegb.org', 'https://cms.savegb.org', 'https://apps.savegb.org']" \
  --set CORS_ALLOW_HEADERS=['*'] \
  --set SECURE_PROXY_SSL_HEADER='["HTTP_X_FORWARDED_PROTO", "https"]'







tutor plugins install minio
tutor plugins enable minio

# Go to Tutor plugins root
PLUGIN_DIR=$(tutor plugins printroot)
mkdir -p $PLUGIN_DIR

cd "$PLUGIN_DIR" || exit 1

# Create plugin file
cat << 'EOF' > skip_email_verification.py
from tutor import hooks

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-common-settings",
        "FEATURES['SKIP_EMAIL_VALIDATION'] = True",
    )
)
EOF

echo "Plugin created: $PLUGIN_DIR/skip_email_verification.py"

tutor plugins enable skip_email_verification

tutor k8s start

kubectl patch storageclass gp3 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# kubectl delete svc caddy -n openedx
# kubectl delete deploy caddy -n openedx

tutor k8s init



# tutor k8s do createuser --staff --superuser admin admin@savegb.org


# tutor k8s do importdemocourse



