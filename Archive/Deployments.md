## Kubernetes Deployment Configuration

One of the ways to deploy a pod to the cluster is through the use of a deployment YAML file. A "deployment" differs in several ways from the other options for instructing kubectl on how to orchestrate your services. More information about these other options can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/

More information about deployments can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

The deployment script below is a simple example with our understanding of what each line is doing.


```yaml
apiVersion: apps/v1 #Specifying the API for Kubernetes
kind: Deployment #Specifying what "controller" construct you're using
metadata: #Metadata for the deployment
  name: nginx-deployment
spec: #Specifications for the deployment
  selector: #Defines how the Deployment finds which Pods to manage
    matchLabels:
      app: nginx #If using "matchLabels" this should match the labels of your pods
  replicas: 2 # Tells deployment to run 2 pods matching the template
  template: #This defines the template of your pod
    metadata: #Metadata for the pod
      labels:
        app: nginx #See above about matchLabels
    spec: #Specification for the pod
      containers: #Specify which containers will run in this pod
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
      nodeSelector: #See note below
        gpu: "false"
```

### nodeSelector Option

We found this option when investigating how to restrict pods to certain nodes. There is a "smarter" option called Node Affinity that allows Kubernetes to try to manage these things in a smarter way, but nodeSelector is the way we experimented with.

More information can be found here: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/

The first step is to attach a label to a node. We attached a label to both the **k8s-compute** node but also to **aquamentus**. 

From the master node:
```{sh}
kubectl label nodes k8s-compute gpu=false
kubectl label nodes aquamentus gpu=true
```

Once these labels were attached, if we deployed a pod using the above deployment.yaml file, it would only be deployed on the **k8s-compute** node. 