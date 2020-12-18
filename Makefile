
.PHONE: deploy
deploy: 
	# print AWS_PROFILE?
	echo $$AWS_PROFILE
	# deploy eks
	terraform init terraform/	
	terraform apply -auto-approve terraform/ 
	# Get eks cluster name from terraform output
	cluster_name=$$(terraform output -json | jq -r '.cluster_id.value'); \
	echo "$$cluster_name"; \
	aws eks --region="us-east-2" update-kubeconfig --name="$$cluster_name"; \
	# Prometheus via helm
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts; \
	helm repo add stable https://charts.helm.sh/stable; \
	helm repo update; \
	# Execute helm
	helm upgrade --install prometheus-lab prometheus-community/kube-prometheus-stack; \
	# Get the password
	secret_name=$$(kubectl get secret --namespace default -o json | jq -r '.items[].metadata | select(.name | contains ("grafana")) | .name' | head -n 1); \
	kubectl get secret --namespace default "$$secret_name"  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo; \
	# Install Rabbitmq
	helm repo add bitnami https://charts.bitnami.com/bitnami || true; \
	helm upgrade --install lab-rabbitmq bitnami/rabbitmq; \
	echo "Username      : user"; \
	echo "Password      : $$(kubectl get secret --namespace default lab-rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 --decode)"; \
	echo "ErLang Cookie : $$(kubectl get secret --namespace default lab-rabbitmq -o jsonpath="{.data.rabbitmq-erlang-cookie}" | base64 --decode)"; \
	# Backend for Vault
	helm install consul hashicorp/consul --values config/helm-consul-values.yml; \
	## Install Vault
	helm repo add hashicorp https://helm.releases.hashicorp.com; \
	helm install consul hashicorp/consul --values config/helm-consul-values.yml; \
	kubectl create ns vault; \
	helm install vault hashicorp/vault;
	# kubectl exec -ti vault-0 -- vault operator init
	# kubectl exec -ti vault-0 -- vault operator unseal 3VKLs87qma6IirFoXp5kDnVQSNWMZYGhi2Lft866ldcD
	# kubectl exec -ti vault-0 -- vault operator unseal m1GWKwbBAud+zCyPSFWV9+Il2AUfEr3XpvZzo0GytOqi
	# kubectl exec -ti vault-0 -- vault operator unseal HjwQJSlj/hIiufwrJk77B893OrH2eRL8f16yPfncDNK4
	# export VAULT_TOKEN=s.iTwt52vIC8yEHvovXf15pAe4
	# export VAULT_ADDR=http://localhost:8200
	# terraform init vault-config/; \
	# vault auth enable aws
	# terraform apply -auto-approve vault-config/; \
	# Need to specify the AWS keys / credencials
	# vault login -method=aws -token-only role=trf-iamrole_vault-config-auth-iam-core
	# alias auth-vault='unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY VAULT_TOKEN VAULT_ADDR; export VAULT_ADDR=http://localhost:8200; export VAULT_TOKEN=$(vault login -method=aws -token-only role=trf-iamrole_vault-config-auth-iam-core);'
	# Install MongoDB
	#  helm install lab-mongodb bitnami/mongodb; \
	# export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace default lab-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode) 
	# kubectl port-forward --namespace default svc/lab-mongodb 27017:27017 &
  # mongo --host 127.0.0.1 --authenticationDatabase admin -p $MONGODB_ROOT_PASSWORD

.PHONE: destroy
destroy:
	terraform destroy terraform/
