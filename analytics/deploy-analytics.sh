ENV_FILE="../.env"

# Load env
[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

kubectl apply -f namespace.yaml

kubectl create secret generic opensearch-credentials \
  --from-literal=host="https://${ELASTICSEARCH_HOST}:443" \
  --from-literal=username="$ELASTICSEARCH_USERNAME" \
  --from-literal=password="$ELASTICSEARCH_PASSWORD" \
  -n analytics

kubectl apply -f logstash.yaml

kubectl apply -f fluentbit.yaml