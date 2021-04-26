# Traefik as an Ingress Controller

## Why?
By default (and without an ingress controller) pods in a cluster can talk to each other but aren't accessible to the outside world. An ingress controller routes traffic from external to the cluster to services inside the cluster. 

## Deployment Configuration:

### Custom Resource Definitions and Cluster Role Bindings:

https://docs.traefik.io/routing/providers/kubernetes-crd/

CRDs determine how the different types of Traefik deals with will be routed.

* IngressRoute: Determines how HTTP traffic will be routed.
* IngressRouteTCP: Determines how TCP traffic will be routed.
* Middleware: Determines how/when requests will be "tweaked" before being passed on.
* TLSOption: Determines how TLS traffic will be handled.

The Cluster Role Bindings specify what the service account associated with the ingress controller can do. This is vital because Traefik needs to be aware of newly created ingress routes... something that other services usually don't need.

Here is the CRD and Cluster Role configuration file:

*customresourcedefinition.yaml*
```yaml
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutes.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRoute
    plural: ingressroutes
    singular: ingressroute
  scope: Namespaced

---
kind: CustomResourceDefinition
metadata:
  name: ingressroutetcps.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRouteTCP
    plural: ingressroutetcps
    singular: ingressroutetcp
  scope: Namespaced

---
kind: CustomResourceDefinition
metadata:
  name: middlewares.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: Middleware
    plural: middlewares
    singular: middleware
  scope: Namespaced

---
kind: CustomResourceDefinition
metadata:
  name: tlsoptions.traefik.containo.us

spec:
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TLSOption
    plural: tlsoptions
    singular: tlsoption
  scope: Namespaced

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: traefik-ingress-controller

rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses/status
    verbs:
      - update
  - apiGroups:
      - traefik.containo.us
    resources:
      - middlewares
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - traefik.containo.us
    resources:
      - ingressroutes
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - traefik.containo.us
    resources:
      - ingressroutetcps
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - traefik.containo.us
    resources:
      - tlsoptions
    verbs:
      - get
      - list
      - watch

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: kube-system
```

This configuration is applied using:
```bash
kubectl apply -f customresourcedefinition.yaml
```

### Pod Configuration:

This configuration sets up the Traefik service account, launches the Traefik pod, and sets up the node port.

* Service Account: This account allows Traefik to contact the api server. As mentioned, this allow it to be aware of new pods.
* Traefik Pod: Not much to say here, need the pod to have Traefik.
* Node Port: A service in Kubernetes abstract a set of pods (although we only have one in this case) to be accessible through a single IP. A Node Port service specifies which port from the service to expose on this IP.

*deployment.yaml*
```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-lb
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: traefik-ingress-lb
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      serviceAccountName: traefik-ingress-controller
      terminationGracePeriodSeconds: 60
      containers:
      - image: traefik:v2.0
        name: traefik-ingress-lb
        ports:
        - name: http
          containerPort: 80
        - name: admin
          containerPort: 8080
        args:
        - --api
        - --api.insecure=true
        # in this case "web" refers to the port name
        # as specified in the service below
        - --entrypoints.web.address=:80
        - --providers.kubernetescrd
        - --accesslog
---
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
    # this is the entrypoint as given in the deploy args
    - protocol: TCP
      port: 80
      name: web
    # this is the dashboard
    - protocol: TCP
      port: 8080
      name: admin
  type: NodePort
```

This configuration is applied using:
```bash
kubectl apply -f deployment.yaml
```