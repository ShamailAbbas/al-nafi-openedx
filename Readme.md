# Open edX Al-Nafi Deployment Guide

## Video Demo

Watch a video demonstration of the full Open edX Al-Nafi deployment:

[▶ Watch Deployment Demo](https://drive.google.com/file/d/1RncE1yI7aJjHYJI5ZJmWq8dp95hA2JYR/view?usp=sharing)

---

## Prerequisites

Before starting, ensure the following are installed and configured:

- Terraform
- kubectl
- Helm
- Domain name (example uses `savegb.org`)
- AWS CLI with sufficient permissions

---

## Step 1: Provision Infrastructure

Navigate to the dev environment and provision AWS infrastructure using Terraform. This step creates:

- Amazon EKS cluster
- VPC networking
- OpenSearch cluster for logging and analytics
- S3 buckets for storage
- RDS for database
- ElastiCache cluster

### Commands

```bash
cd infra/environment/dev
terraform init
terraform apply --auto-approve
```

**Note:** Terraform will provision all AWS resources. This may take 10–15 minutes.

---

## Step 2: Load Environment Variables

The `getcreds.sh` script extracts Terraform outputs and sets up Kubernetes context.

### Commands

```bash
bash getcreds.sh
```

**Result:**

- Environment variables for database connections, cache endpoints, and other infrastructure are exported.
- Kubernetes context is configured.

---

## Step 3: Deploy Nginx Ingress Controller and Cert-Manager

### Commands

```bash
cd ../../../nginx
bash deploy-nginx.sh
```

**Notes:**

- Update domain names in the configuration files to match your own domain.
- Copy the ALB endpoint and create CNAME records in your DNS.

---

## Step 4: Deploy MongoDB

Deploy MongoDB cluster with persistent storage.

### Commands

```bash
cd ../mongodb
bash deploy.sh
```

**Result:** MongoDB StatefulSet and PVCs are deployed on Kubernetes.

---

## Step 5: Deploy Open edX Platform

Deploy the full Open edX stack:

- LMS at `savegb.org`
- CMS/Studio at `cms.savegb.org`
- Micro-Frontend Applications at `apps.savegb.org`

### Commands

```bash
cd ../openedx
bash deploy-openedx.sh
```

**Result:** Open edX components are deployed with Helm/Tutor and SSL certificates are configured.

---

## Step 6: Configure WAF and CDN

Deploy AWS WAF rules and CloudFront CDN.

### Commands

```bash
cd ../waf_cdn
terraform init
terraform apply --auto-approve
```

**Result:** Traffic is filtered for security, and CDN is enabled for global delivery.

---

## Step 7: Deploy Monitoring Stack

Set up monitoring with Prometheus and Grafana.

### Commands

```bash
cd ../monitoring
bash deploy-monitoring.sh
```

**Result:**

- Metrics collection.
- Grafana dashboards are available for visualization.

---

## Step 8: Deploy AWS ALB Controller

### Commands

```bash
cd ../cluster
bash setup-alb-controller.sh
```

**Result:** Kubernetes ingress can now use AWS ALB for external access.

---

## Step 9: Deploy Analytics Stack

Deploy Fluentbit, Logstash, and OpenSearch for logging and analytics.

### Commands

```bash
cd ../analytics
bash deploy-analytics.sh
```

**Result:**

- Logs are collected from all pods via Fluentbit.
- Logstash processes logs and sends them to OpenSearch.
- Logs become searchable in OpenSearch dashboards.

---

## Step 10: Configure HPA and Cluster Autoscaler

### A) Deploy Metrics Server and HPA

```bash
cd ../openedx
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f hpa.yaml
```

**Result:** Horizontal Pod Autoscaler (HPA) scales LMS, CMS, and worker pods based on CPU and memory usage.

### B) Deploy Cluster Autoscaler

```bash
cd ../cluster
bash cluster-autoscaler.sh
```

**Result:** Cluster Autoscaler adjusts EC2 node count based on pod scheduling requirements and resource utilization.

---



## Step 11: Load Generation

### Commands

This script will generate 300 concurrent requests for 10 minutes using k6. k6 must be installed on the system

```bash
k6 run load.js
```


## Step 12: Cleanup

### Commands

This script will delete everything

```bash
bash destroy-all.sh
```



---
