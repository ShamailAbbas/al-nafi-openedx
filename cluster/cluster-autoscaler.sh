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



ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IAM_POLICY_NAME="ClusterAutoscalerPolicy"
SERVICE_ACCOUNT_NAMESPACE="kube-system"
SERVICE_ACCOUNT_NAME="cluster-autoscaler"



aws iam create-policy \
  --policy-name $IAM_POLICY_NAME \
  --policy-document file://iam-for-autoscaler.json || echo "Policy may already exist"

echo ">>> Creating IAM role for Cluster Autoscaler with OIDC trust..."
eksctl utils associate-iam-oidc-provider \
  --region $AWS_REGION \
  --cluster $CLUSTER_NAME \
  --approve

eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --namespace $SERVICE_ACCOUNT_NAMESPACE \
  --name $SERVICE_ACCOUNT_NAME \
  --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/$IAM_POLICY_NAME \
  --override-existing-serviceaccounts \
  --approve

echo ">>> Installing Cluster Autoscaler via Helm..."
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm upgrade -i cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace $SERVICE_ACCOUNT_NAMESPACE \
  --set autoDiscovery.clusterName=$CLUSTER_NAME \
  --set awsRegion=$AWS_REGION \
  --set rbac.create=true \
  --set serviceAccount.name=$SERVICE_ACCOUNT_NAME \
  --set serviceAccount.create=false

echo ">>> Cluster Autoscaler setup completed successfully!"
