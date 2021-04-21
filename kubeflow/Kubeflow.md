# Kubeflow Install

The primary resource for this document is here (Kubeflow v1.3 GitHub repo): https://github.com/kubeflow/manifests. You should clone this in order to get started.

## Prereqs

This install assumes you have a default storage provider installed as well as a SSL certificate secret in the *istio-system* namespace.

## Install

Once in the cloned repo, you should copy *ingress.yaml* and *dex-config.yaml* into the folder. You can then install all the components using a single command (individual component install commands are available on the repo).  

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