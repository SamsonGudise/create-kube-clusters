default: plan
	
kubecfg:
	(terraform output eks-kubeconfig > ~/.kube/eksconfig)
	(terraform output aks-kubeconfig > ~/.kube/aksconfig)
	(terraform output gke-kubeconfig > ~/.kube/gkeconfig)

init:
	terraform init -backend-config=backend.tfvars

plan:
	terraform init -backend-config=backend.tfvars
	terraform plan -out tfplan.out

apply:
	terraform apply tfplan.out

destroy:
	terraform destroy

clean:
	rm -rf .terraform