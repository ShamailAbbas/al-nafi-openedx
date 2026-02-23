############# Provision Infrastructure ####################

# Navigate to the dev environment directory
cd infra/environment/dev

# Initialize Terraform (downloads required providers and modules)
terraform init

# Apply the Terraform configuration to create all infrastructure resources
terraform apply --auto-approve


######################### Get Environment Variables #####################
bash getcreds.sh


###########Deploy nginx ###########
# Navigate to nginx directory
cd ../../../nginx

# Run the deployment script
bash deploy-nginx.sh


###########Deploy MongoDB###########
cd ../mongodb

# Run the deployment script
bash deploy.sh


###########Deploy OpenEdx###########
cd ../openedx

# Run the deployment script
bash deploy-openedx.sh


###########Configure WAF and CDN ###########
# Navigate to waf_cdn directory
cd ../waf_cdn
terraform init

terraform apply --auto-approve


###########Deploy ingress and cert manager###########
# Navigate to nginx directory
cd ../nginx

# Run the deployment script
bash deploy-ingress.sh



#################Deploy monitoring stack##################
# Navigate to monitoring directory


cd ../monitoring

bash deploy-monitoring.sh


# Navigate to cluster directory and set up ALB controller

cd ../cluster
bash setup-alb-controller.sh



############Deploy Anlytics Stack###################
# Navigate to analytics directory
cd ../analytics

bash deploy-analytics.sh






########################## Configure HPA for OpenEdx LMs and CMS##################
# Navigate to openedx directory
cd ../openedx

bash configure-hpa.sh




###################### Configure Cluster Auto Scaler #####################
# Navigate to cluster directory
cd ../cluster

# Deploy the cluster autoscaler
bash cluster-autoscaler.sh
