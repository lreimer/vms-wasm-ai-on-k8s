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


```

## WASM in Action

```bash
```

## AI Workloads in Action

```bash
# model deployment using CLI
kollama deploy llama3.1
kubectl get models
kollama expose llama3.1 --service-name=ollama-model-llama31-lb --service-type=LoadBalancer

# model deployment via CRD
kubectl apply -f infrastructure/models/deepseek-r1.yaml
kubectl get models
kollama expose deepseek-r1 --service-type LoadBalancer

# to start a chat with ollama
# exchange localhost with the actual LoadBalancer IP
OLLAMA_HOST=localhost:11434 ollama run llama3.1
OLLAMA_HOST=localhost:11434 ollama run deepseek-r1:8b

# call the chat API of Ollama or OpenAI
kubectl port-forward svc/ollama-model-llama31-lbcurl  ollama
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
