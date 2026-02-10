# Open edX Deployment Guide

## VIDEO Demo

You can watch a demo of the project [here](https://www.loom.com/share/b6aecb00d3de4cda9001bbfbb2844918).


## Prerequisites
- Terraform installed
- kubectl configured
- Helm installed
- Domain name ready (example uses savegb.org)

---

## Step 1: Deploy Infrastructure

We have multiple environments available. For this demo, we will deploy in the **dev environment**. 

All infrastructure is managed as code using **Terraform**. This step will provision:
- OpenSearch cluster for logging and analytics
- Amazon EKS (Elastic Kubernetes Service) cluster
- VPC (Virtual Private Cloud) networking
- S3 buckets for storage
- EC2 instance with MongoDB database
- RDS as database
- ElastiCache for caching

**Note:** CDN and WAF are not included due to time constraints.

### Commands:

```bash
# Navigate to the dev environment directory
cd infra/environment/dev

# Initialize Terraform (downloads required providers and modules)
terraform init

# Apply the Terraform configuration to create all infrastructure resources
terraform apply --auto-approve
```

**What happens:** Terraform will create all the AWS resources defined in the configuration files. This process may take 10-15 minutes.

---

## Step 2: Load Environment Variables

After the infrastructure is deployed, you need to load the necessary environment variables that Open edX will use to connect to the infrastructure components.

The `getcreds.sh` script is located in the `infra/environment/dev` folder and will:
- Extract credentials from Terraform outputs
- Set up Kubernetes context
- Export environment variables for database connections, cache endpoints, etc.

### Commands:

```bash
# Run the script to load environment variables
bash getcreds.sh
```

**What happens:** This script configures your terminal session with all the necessary credentials and endpoints.

---

## Step 3: Deploy Open edX Platform

Now we'll deploy the Open edX platform itself on the EKS cluster. This deployment will set up:
- **LMS** (Learning Management System) at `savegb.org`
- **Studio/CMS** (Content Management System) at `cms.savegb.org`
- **MFE** (Micro-Frontend Applications) at `apps.savegb.org`

The `deploy.sh` script will:
1. Deploy nginx-ingress controller
2. Deploy cert-manager for SSL/TLS certificates
3. Deploy the Open edX platform using Helm charts and tutor

### Commands:

```bash
# Navigate to the openedx directory
cd ../../../openedx

# Run the deployment script
bash deploy.sh
```

**Important:** 
- Make sure to update the domain names in the configuration files to match your own domain
- After running the script, you'll be prompted to add DNS records
- Copy the ALB (Application Load Balancer) endpoint and create CNAME records in your domain's DNS settings

**What happens:** The script deploys all Open edX components to your Kubernetes cluster and configures SSL certificates.

---

## Step 4: Deploy Grafana and Prometheus for Monitoring

This step sets up comprehensive monitoring for your cluster using:
- **Prometheus** for metrics collection
- **Grafana** for visualization dashboards

### Commands:

```bash
# Navigate to cluster directory and set up ALB controller
cd ../cluster
bash setup-alb-controller.sh

# Navigate to monitoring directory
cd ../monitoring

# Create the monitoring namespace and storage class
kubectl apply -f namespaces.yaml
kubectl apply -f storageclass.yaml

# Add Helm repositories for Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus stack with custom values
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f values.yaml

# Deploy ingress resources for external access
kubectl apply -f grafana-ingress.yaml
kubectl apply -f prometheus-ingress.yaml

# Get the ingress URLs for Grafana and Prometheus
kubectl get ingress -n monitoring
```

**What happens:** 
- Prometheus begins collecting metrics from all cluster components
- Grafana is configured with pre-built dashboards
- Ingress resources expose both services externally

**Access Details:**
- **Grafana default credentials:** Username: `admin` / Password: `admin` (you'll be prompted to change this on first login)
- Use the ingress URLs displayed by the last command to access the interfaces

---

## Step 5: Deploy Fluentbit and Logstash

This step sets up the logging pipeline to collect, process, and ship logs to OpenSearch for analysis.

**Components:**
- **Fluentbit** - Lightweight log collector running on each node
- **Logstash** - Log processing and transformation
- **OpenSearch** - Log storage and analysis

### Prerequisites:
Before running these commands, you must:
1. Locate the OpenSearch endpoint from the Terraform output in Step 1
2. Update the OpenSearch URL in `analytics/logstash.yaml` file

### Commands:

```bash
# Navigate to analytics directory
cd ../analytics

# Create the analytics namespace
kubectl apply -f namespace.yaml

# Deploy all logging components (Fluentbit and Logstash)
kubectl apply -f .
```

**What happens:** 
- Fluentbit DaemonSet is deployed to collect logs from all pods
- Logstash processes and forwards logs to OpenSearch
- Logs become searchable in OpenSearch Dashboards

**OpenSearch Access Details:**
- **Username:** `admin`
- **Password:** `Admin123!`
- Use the OpenSearch endpoint URL to access dashboards

---

## Step 6: HPA and Cluster Scaling

This step configures automatic scaling at two levels:
1. **Horizontal Pod Autoscaler (HPA)** - Scales individual pods based on CPU/memory usage
2. **Cluster Autoscaler** - Scales EC2 nodes in the cluster based on resource demand

### Part A: Deploy Metrics Server and HPA

The Metrics Server collects resource metrics from Kubernetes and makes them available for autoscaling decisions.

```bash
# Navigate to openedx directory
cd ../openedx

# Deploy Kubernetes Metrics Server (required for HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Apply HPA configurations for LMS, CMS, and worker pods
kubectl apply -f hpa.yaml
```

**What happens:** 
- Metrics Server begins collecting CPU and memory metrics
- HPA configurations are applied to automatically scale:
  - LMS pods
  - CMS pods
  - Worker pods (for background tasks)

### Part B: Deploy Cluster Autoscaler

The Cluster Autoscaler automatically adjusts the number of nodes in your cluster.

```bash
# Navigate to cluster directory
cd ../cluster

# Deploy the cluster autoscaler
bash cluster-autoscaler.sh
```

**What happens:** 
- Cluster Autoscaler monitors pod resource requests
- Automatically adds nodes when pods can't be scheduled due to insufficient resources
- Removes underutilized nodes to save costs

---

## Step 7: Cleanup

When you're done with the deployment and want to tear down all resources:

### Commands:

```bash
# First, delete all Kubernetes ingress resources
# (This prevents ALB resources from being orphaned)
kubectl delete ingress --all --all-namespaces

# Navigate back to the Terraform directory
cd ../infra/environment/dev

# Destroy all infrastructure resources
terraform destroy
```

**What happens:** 
- Terraform removes all AWS resources created in Step 1
- This includes EKS cluster, VPC, databases, storage, etc.


**Important:** Always delete ingress resources first to ensure that AWS Load Balancers are properly removed before destroying the infrastructure.

---
