default: plan
	
kubecfg:
	(terraform output eks-kubeconfig > ~/.kube/eksconfig)

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