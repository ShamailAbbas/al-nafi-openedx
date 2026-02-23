#!/bin/bash


ENV_FILE="../.env"

echo ">>> Loading environment variables from $ENV_FILE..."
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
    echo "Environment variables loaded successfully"
else
    echo "ERROR: $ENV_FILE not found!"
    exit 1
fi

# Validate required env vars
for var in AWS_REGION CLUSTER_NAME; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: $var is not set in $ENV_FILE"
        exit 1
    fi
done

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$ACCOUNT_ID" ]; then
    echo "ERROR: Failed to fetch AWS Account ID. Check your AWS credentials."
    exit 1
fi

IAM_POLICY_NAME="ClusterAutoscalerPolicy"
SERVICE_ACCOUNT_NAMESPACE="kube-system"
SERVICE_ACCOUNT_NAME="cluster-autoscaler"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"

# -------------------------------------------------------
# Inline hardened policy — no jq or external file needed
# -------------------------------------------------------
echo ">>> Creating IAM policy document..."
cat > /tmp/iam-for-autoscaler.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeScalingActivities",
                "autoscaling:DescribeTags",
                "ec2:DescribeImages",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:GetInstanceTypesFromInstanceRequirements",
                "eks:DescribeNodegroup"
            ],
            "Resource": ["*"]
        },
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": ["*"],
            "Condition": {
                "StringEquals": {
                    "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled": "true",
                    "autoscaling:ResourceTag/kubernetes.io/cluster/${CLUSTER_NAME}": "owned"
                }
            }
        }
    ]
}
EOF

echo ">>> Checking if IAM policy exists..."
if ! aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo ">>> Creating IAM policy..."
    aws iam create-policy \
        --policy-name "$IAM_POLICY_NAME" \
        --policy-document file:///tmp/iam-for-autoscaler.json
    echo "IAM policy created successfully"
else
    echo ">>> IAM policy already exists, skipping creation..."
fi

echo ">>> Associating OIDC provider..."
eksctl utils associate-iam-oidc-provider \
    --region "$AWS_REGION" \
    --cluster "$CLUSTER_NAME" \
    --approve

echo ">>> Creating IAM service account..."
if eksctl get iamserviceaccount \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --namespace "$SERVICE_ACCOUNT_NAMESPACE" \
    --name "$SERVICE_ACCOUNT_NAME" &>/dev/null; then
    echo ">>> IAM service account already exists, skipping..."
else
    eksctl create iamserviceaccount \
        --cluster "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --namespace "$SERVICE_ACCOUNT_NAMESPACE" \
        --name "$SERVICE_ACCOUNT_NAME" \
        --attach-policy-arn "$POLICY_ARN" \
        --override-existing-serviceaccounts \
        --approve
fi

echo ">>> Installing Cluster Autoscaler via Helm..."
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm upgrade -i cluster-autoscaler autoscaler/cluster-autoscaler \
    --namespace "$SERVICE_ACCOUNT_NAMESPACE" \
    --set autoDiscovery.clusterName="$CLUSTER_NAME" \
    --set awsRegion="$AWS_REGION" \
    --set rbac.create=true \
    --set serviceAccount.name="$SERVICE_ACCOUNT_NAME" \
    --set serviceAccount.create=false \
    --set extraArgs.balance-similar-node-groups=true \
    --set extraArgs.skip-nodes-with-system-pods=false \
    --set extraArgs.scale-down-utilization-threshold=0.7 \
    --set extraArgs.scale-down-delay-after-add=5m \
    --set extraArgs.scale-down-unneeded-time=10m

echo ">>> Verifying deployment..."
kubectl rollout status deployment/cluster-autoscaler \
    -n "$SERVICE_ACCOUNT_NAMESPACE" \
    --timeout=120s

# Cleanup
rm -f /tmp/iam-for-autoscaler.json

echo ">>> Cluster Autoscaler setup completed successfully!"