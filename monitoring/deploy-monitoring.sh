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