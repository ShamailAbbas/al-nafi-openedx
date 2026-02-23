
echo ">>> Step 1: Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo ">>> Step 2: Patching metrics-server for EKS (kubelet TLS)..."
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
  }
]'

echo ">>> Step 3: Patching resource requests on OpenedX deployments..."

kubectl patch deployment lms -n openedx --type='json' -p='[{
  "op": "add",
  "path": "/spec/template/spec/containers/0/resources",
  "value": {
    "requests": { "cpu": "200m", "memory": "800Mi" },
    "limits":   { "cpu": "1000m", "memory": "2Gi" }
  }
}]'
echo "    lms patched"

kubectl patch deployment lms-worker -n openedx --type='json' -p='[{
  "op": "add",
  "path": "/spec/template/spec/containers/0/resources",
  "value": {
    "requests": { "cpu": "200m", "memory": "800Mi" },
    "limits":   { "cpu": "1000m", "memory": "2Gi" }
  }
}]'
echo "    lms-worker patched"

kubectl patch deployment cms -n openedx --type='json' -p='[{
  "op": "add",
  "path": "/spec/template/spec/containers/0/resources",
  "value": {
    "requests": { "cpu": "200m", "memory": "700Mi" },
    "limits":   { "cpu": "1000m", "memory": "2Gi" }
  }
}]'
echo "    cms patched"

kubectl patch deployment cms-worker -n openedx --type='json' -p='[{
  "op": "add",
  "path": "/spec/template/spec/containers/0/resources",
  "value": {
    "requests": { "cpu": "200m", "memory": "800Mi" },
    "limits":   { "cpu": "1000m", "memory": "2Gi" }
  }
}]'
echo "    cms-worker patched"

echo ">>> Step 4: Applying HPA manifests..."
kubectl apply -f hpa.yaml





