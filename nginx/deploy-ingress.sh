# Install cert-manager if not present
if ! kubectl get ns cert-manager >/dev/null 2>&1; then
  echo "Installing cert-manager..."
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.yaml

  # Wait for all three core deployments, not just the main one
  for deploy in cert-manager cert-manager-webhook cert-manager-cainjector; do
    echo "  waiting for $deploy..."
    kubectl wait --for=condition=available deployment/"$deploy" \
      -n cert-manager --timeout=180s
  done
else
  echo "cert-manager already installed, skipping."
fi

# Give the webhook a moment to become fully ready before applying CRDs

echo "Waiting for cert-manager webhook to be reachable..."
sleep 120

# Apply issuer + ingress
echo "Applying letsencrypt-issuer.yaml..."
kubectl apply -f letsencrypt-issuer.yaml

echo "Applying ingress.yaml..."
kubectl apply -f ingress.yaml

echo "Installed ingress"