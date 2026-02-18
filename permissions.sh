#!/bin/bash
# Fix Block Public Access settings on existing buckets created by MinIO

# Set your AWS region
REGION="us-east-2"  # Change this to your region

# Bucket names (use the actual names from your MinIO logs)
STORAGE_BUCKET="openedx-storage-bucket-alnafi-2026"
VIDEOS_BUCKET="openedxvideos"
LEARNING_BUCKET="openedxlearning"

echo "Disabling Block Public Access on buckets..."

# Allow public policies on storage bucket
aws s3api put-public-access-block \
    --bucket "$STORAGE_BUCKET" \
    --region "$REGION" \
    --public-access-block-configuration \
        "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

echo "✓ Updated $STORAGE_BUCKET"

# Allow public policies on videos bucket
aws s3api put-public-access-block \
    --bucket "$VIDEOS_BUCKET" \
    --region "$REGION" \
    --public-access-block-configuration \
        "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

echo "✓ Updated $VIDEOS_BUCKET"

# Allow public policies on learning bucket
aws s3api put-public-access-block \
    --bucket "$LEARNING_BUCKET" \
    --region "$REGION" \
    --public-access-block-configuration \
        "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

echo "✓ Updated $LEARNING_BUCKET"

echo ""
echo "Done! Now restart the MinIO job:"
echo "kubectl delete job -l app.kubernetes.io/component=job -n openedx"
echo "tutor k8s init"