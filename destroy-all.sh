#!/bin/bash
set -euo pipefail

ENV_FILE=".env"

# Load env
[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a


kubectl delete ingress --all --all-namespaces
kubectl delete svc --all --all-namespaces

echo 'Deleted all ingresses and services'

# Remove S3 bucket contents
aws s3 rm "s3://${S3_STORAGE_BUCKET}" --recursive


echo "Deleted all objects in the ${S3_STORAGE_BUCKET} bucket"

# Destroy Terraform infrastructure
cd infra/environment/dev
terraform destroy --auto-approve

echo "Destroyed Infra"

cd ../../../waf_cdn
terraform destroy --auto-approve

echo "Destroyed waf and cnd"