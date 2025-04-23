GCP_PROJECT ?= cloud-native-experience-lab
GCP_REGION ?= europe-west4
KUBEVIRT_VERSION ?= v1.5.0
CDI_VERSION ?= $(shell basename `curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest`)

prepare-gcp:
	@gcloud config set project $(GCP_PROJECT)
	@gcloud config set container/use_client_certificate False

create-gke-cluster:
	@gcloud container clusters create vms-wasm-ai \
		--release-channel=regular \
		--region=$(GCP_REGION)  \
		--cluster-version=1.32 \
		--addons=HttpLoadBalancing,HorizontalPodAutoscaling,GcePersistentDiskCsiDriver,ConfigConnector \
		--workload-pool=$(GCP_PROJECT).svc.id.goog \
		--machine-type=n1-standard-8 \
		--accelerator type=nvidia-tesla-t4,count=1 \
		--local-ssd-count=1 \
		--enable-autoscaling \
        --num-nodes=1 \
		--min-nodes=1 --max-nodes=5 \
		--enable-autorepair \
		--enable-ip-alias \
		--enable-nested-virtualization \
		--node-labels=nested-virtualization=enabled \
		--logging=SYSTEM \
        --monitoring=SYSTEM
	@kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$$(gcloud config get-value core/account)
	@kubectl cluster-info
	@kubectl label node --all node-role.kubernetes.io/worker=""

bootstrap-kubevirt:
	@kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-operator.yaml
	@kubectl create -f kubevirt/kubevirt-cr.yaml

bootstrap-cdi:
	@kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/${CDI_VERSION}/cdi-operator.yaml
	@kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/${CDI_VERSION}/cdi-cr.yaml

bootstrap-ollama:
	@kubectl create -k ollama/	

delete-gke-cluster:
	@gcloud container clusters delete vms-wasm-ai --region=$(GCP_REGION) --async --quiet
