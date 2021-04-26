# Kubeflow Install

The primary resource for this document is here (Kubeflow v1.3 GitHub repo): https://github.com/kubeflow/manifests. You should clone this in order to get started.

## Prereqs

This install assumes you have a default storage provider installed as well as a SSL certificate secret in the *istio-system* namespace.

## Preparation

Once in the cloned repo, you should copy *ingress.yaml* and *dex-config.yaml* into the folder. 

You will need to make a few small changes to ensure that new users are on-boarded correctly. In **manifests/apps/centraldashboard/upstream/base/params.env** make this change:

```{yaml}
CD_REGISTRATION_FLOW=true
```

Also, we need to allow the ingressgateway to listen on HTTPS and add a connection to the SSL certficate secret by adding these lines to end of **manifests/common/istio-1-9-0/kubeflow-isitio-resources/base/kf-istio-resources.yaml**.

```{yaml}
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
  ### New lines below
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "*"
    tls:
      mode: SIMPLE
      credentialName: k8s.eecs.net

```

Finally, in order to integrate with the shared GPU solution in use at the time of writing this guide, you will need to change what the Jupyter spawner "looks for" when allowing users to spawn notebooks with GPU access. You will make these change in the file **manifests/apps/jupyter/upstream/base/configs/spawner_ui_config.yaml**:

```{yaml}
 gpus:
    value:
      num: "none"
      vendors:
      - limitsKey: "deepomatic.com/shared-gpu" ##This is the change
        uiName: "NVIDIA"
      vendor: ""
    readOnly: false
```

There are a lot of options that are configured in this file, it's probably an important one to read through.

## Install

You can then install all the components using a single command (individual component install commands are available on the repo).  

```{bash}
while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done
```

This might take a little while to install all the necessary components. After that is complete, you will want to add the ingress using the command below:

```{bash}
kubectl apply -f ingress.yaml
```

Finally, to use the EECSNet LDAP server for authentication, you can update the Dex configuration using these commands:

```{bash}
kubectl create configmap dex --from-file=config.yaml=dex-config.yaml -n auth --dry-run -oyaml | kubectl apply -f -
kubectl rollout restart deployment dex -n auth
```

