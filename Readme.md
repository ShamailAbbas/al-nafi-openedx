# Open edX Deployment Guide

## Prerequisites
- Terraform installed
- kubectl configured
- Helm installed
- Domain name ready (example uses savegb.org)

## Step 1: Deploy Infrastructure

We have multiple environments. For this demo we will deploy in dev environment. We have all the infra as code using Terraform. This deploy opensearch, eks, vpc, s3, an ec2 instance with mongodb, elastic cache ( cdn and waf still remaing due to time constraints )

```bash
cd infra/environment/dev
terraform init
terraform apply --auto-approve
```

## Step 2: Load Environment Credentials

Run this script to load the env needed for the Open edX platform. This script is in the `infra/environment/dev` folder.

```bash
bash getcreds.sh
```

## Step 3: Deploy Open edX Platform

Go to openedx directory and apply this code to deploy the Open edX. This will use `savegb.org` for LMS and `cms.savegb.org` for Studio and `apps.savegb.org` for MFA.

Make sure to change to your domain and add the ALB ingress to your domain records. You will be prompted to add the records when you run this script. This script will deploy nginx-ingress and cert manager and then deploy openedx platform

```bash
cd ../../../openedx
bash deploy.sh
```

## Step 4: Deploy Grafana and Prometheus for Monitoring

```bash
cd ../monitoring

kubectl apply -f namespaces.yaml
kubectl apply -f storageclass.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f values.yaml

kubectl apply -f grafana-ingress.yaml
kubectl apply -f prometheus-ingress.yaml

kubectl get ingress -n monitoring
```

You can access Grafana and Prometheus using the ingress URL.

**Grafana default credentials:** `admin` / `admin`

## Step 5: Deploy Fluentbit and Logstash

Deploy Fluentbit and Logstash to ship logs to OpenSearch. Make sure to update the URL of the output in `analytics/logstash.yaml` to the OpenSearch endpoint you get when you apply the above terraform apply code. After updating, apply the bash commands.

```bash
cd ../analytics

kubectl apply -f namespace.yaml
kubectl apply -f .
```

OpenSearch is used for logs analytics and its credentials are:
- **User:** `admin`
- **Password:** `Admin123!`

## Step 6: Cleanup

Delete all ingresses and then apply:

```bash
cd ../infra/environment/dev
terraform destroy
```