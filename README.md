# Beyond Microservices: Running VMs, WASM, and AI Workloads on Kubernetes

## Setup

```bash
# for GKE we need to enable nested virtualization
# not all machine types support this feature, see https://cloud.google.com/compute/docs/machine-resource?hl=en#machine_type_comparison
# otherwise make sure your Kube context points to your local cluster
make create-gke-cluster

# remember, once you are finished to destroy the cluster
make delete-gke-cluster
```

## VMs in Action

```bash
# next we bootstrap kubevirt onto the cluster
# this will install the operator and custom resource as describe in https://kubevirt.io/quickstart_cloud/
make bootstrap-kubevirt
kubectl krew install virt

# check the status of all components, must be deployed status
kubectl get all -n kubevirt
kubectl get kubevirt -n kubevirt

# (optional) deploy the containerized data importer components
make bootstrap-cdi
kubectl get pods -n cdi

# first we create our first VM
kubectl apply -f kubevirt/testvm.yaml
kubectl get vms

# we start and check that the VM instance is running
kubectl virt start testvm
kubectl get vmis
kubectl virt console testvm

# next we check the cluster internal communication
kubectl apply -f kubevirt/testshell.yaml
kubectl get vmis
kubectl exec -it testshell -- /bin/sh
ping <IP>

# now expose the SSH port of the VM and connect to it
kubectl virt expose vmi testvm --name=testvm-ssh --port=20222 --target-port=22 --type=LoadBalancer
kubectl get services
ssh cirros@<EXTERNAL-IP> -p 20222

# there are also machine instance replica sets, this one can also be scaled
kubectl apply -f kubevirt/testreplicaset.yaml
kubectl virt expose vmirs testreplicaset --name=testreplicaset-ssh --port=22222 --target-port=22
kubectl get vmis

kubectl scale vmirs testreplicaset --replicas=2
kubectl get vmis

kubectl apply -f kubevirt/testhpa.yaml
kubectl get vmis
kubectl scale vmirs testreplicaset --replicas=3
kubectl describe hpa testhpa
kubectl get vmis
```

## WASM in Action

```bash
# install the prerequisites 
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
kubectl get all -n cert-manager

# Add Helm repository if not already done
helm repo add kwasm http://kwasm.sh/kwasm-operator/

# Install KWasm operator
helm install \
  kwasm-operator kwasm/kwasm-operator \
  --namespace kwasm \
  --create-namespace \
  --set kwasmOperator.installerImage=ghcr.io/spinframework/containerd-shim-spin/node-installer:v0.19.0

# Provision Nodes
# Once cluster has scaled, make sure to apply the annotations again
kubectl annotate node --all kwasm.sh/kwasm-node=true

kubectl apply -f https://github.com/spinframework/spin-operator/releases/download/v0.5.0/spin-operator.crds.yaml
kubectl apply -f https://github.com/spinframework/spin-operator/releases/download/v0.5.0/spin-operator.runtime-class.yaml
kubectl apply -f https://github.com/spinframework/spin-operator/releases/download/v0.5.0/spin-operator.shim-executor.yaml

helm install spin-operator \
  --namespace spin-operator \
  --create-namespace \
  --version 0.5.0 \
  --wait \
  oci://ghcr.io/spinframework/charts/spin-operator

# try out the official Spin demo app
kubectl apply -f https://raw.githubusercontent.com/spinframework/spin-operator/main/config/samples/simple.yaml
kubectl port-forward svc/simple-spinapp 8083:80
curl localhost:8083/hello

# build and deploy some Spin applications
cd examples/

spin new -t http-rust hello-spinkube --accept-defaults
cd hello-spinkube

spin build
spin registry push ttl.sh/hello-spinkube:1h
spin kube scaffold --from ttl.sh/hello-spinkube:1h
spin kube deploy --from ttl.sh/hello-spinkube:1h
kubectl get spinapps
kubectl port-forward svc/hello-spinkube 8084:80
curl localhost:8084/spinkube

# nother webserver demo to serve files
spin new -t static-fileserver hello-webserver --accept-defaults
cd hello-webserver

spin build
spin registry push ttl.sh/hello-webserver:1h
spin kube scaffold --from ttl.sh/hello-webserver:1h
spin kube deploy --from ttl.sh/hello-webserver:1h
kubectl get spinapps
kubectl port-forward svc/hello-webserver 8085:80
open http://localhost:8085/static/index.html
```

## AI Workloads in Action

```bash
# model deployment using CLI
kollama deploy llama3.1
kubectl get models
kollama expose llama3.1 --service-name=ollama-model-llama31-lb --service-type=LoadBalancer

# model deployment via CRD
kubectl apply -f ollama/deepseek-r1.yaml
kubectl get models
kollama expose deepseek-r1 --service-type LoadBalancer

# to start a chat with ollama
# !! exchange localhost with the actual LoadBalancer IP, or use port-forward
OLLAMA_HOST=localhost:11434 ollama run llama3.1
OLLAMA_HOST=localhost:11434 ollama run deepseek-r1:8b

# call the chat API of Ollama or OpenAI
kubectl port-forward svc/ollama-model-llama31-lbcurl ollama
curl http://localhost:11434/v1/chat/completions -H "Content-Type: application/json" -d '{
    "model": "llama3.1",
    "messages": [
      {
        "role": "user",
        "content": "Say this is a test!"
      }
    ]
  }'

kubectl port-forward svc/ollama-model-deepseek-r1-lb ollama
curl http://localhost:11434/v1/chat/completions -H "Content-Type: application/json" -d '{
    "model": "deepseek-r1:8b",
    "messages": [
      {
        "role": "user",
        "content": "Say this is a test!"
      }
    ]
  }'
```

## Maintainer

M.-Leander Reimer (@lreimer), <mario-leander.reimer@qaware.de>

## License

This software is provided under the MIT open source license, read the `LICENSE`
file for details.
