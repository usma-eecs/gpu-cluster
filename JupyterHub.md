## Install JupyterHub Chart

The first step is to add the JupyterHub Helm chart repository in the *Apps & Marketplace* section of **Cluster Explorer**. Use this link: https://jupyterhub.github.io/helm-chart/

Once Rancher has downloaded these charts, you can install JupyterHub. The *yaml* file in this repository represents the current configuration for JupyterHub on the cluster. There are a couple keys changes that should be understood for potential future modification/upgrades.

## User Pod Profiles
There is a section under the *singleuser* section of the chart that allows the user to choose a particular profile for the container. There is a default image defined under *singleuser -> image* and then will be overridden if appropriate by the various profiles. Also note the *deepomatic.com/shared-gpu: '1'* to ensure that any pods using that profile will spawn on a GPU-equipped node.

```{yaml}
singleuser:
    image:
        name: jupyter/minimal-notebook
        pullPolicy: ''
        pullSecrets: []
        tag: 3395de4db93a
    profileList:
        - default: true
          description: 'To avoid too much bells and whistles: Python.'
          display_name: Minimal environment
    - description: 'If you want the additional bells and whistles: Python, R, and Julia.'
      display_name: Datascience environment
      kubespawner_override:
        image: 'jupyter/datascience-notebook:3395de4db93a'
    - description: CUDA Environment
      display_name: Container built with CUDA support.
      kubespawner_override:
        extra_resource_limits:
          deepomatic.com/shared-gpu: '1'
        image: 'cdasdsp/dsp-notebook:2077'
```

### Couple Notes for the GPU/CUDA Profile(s)
* At the start, we set up the container image as the top-level of the docker stack for the Math Deparment's "Data Science Playground" JupyterHub environment because it was known to work with CUDA. Eventually this should be transitioned to another image because of some customizations in the DSP image. Whatever image is used, the easiest way to ensure that the GPUs function is to base the image on one of Nvidia's CUDA images.
* The environmental variable *TF_FORCE_GPU_ALLOW_GROWTH = TRUE* should be set in the container to ensure that a user doesn't reserve all the GPU memory when they start a job.

## Node Labels for Scheduling
We've tried to keep the "core pods" of JupyterHub off of the GPU nodes because of the extra bit of high-availability offered by the VMs being on vSphere. There is an option in the Helm chart to require that these pods are scheduled on labeled nodes.

```{yaml}
scheduling:
  corePods:
    nodeAffinity:
      matchNodePurpose: require
```

We added these labels to the VM nodes to allow the scheduling of these pods.
```{bash}
hub.jupyter.org/node-purpose=core
```

## Admin Users
A set of users should be provided administrative access in JupyterHub. When using the EECSNet LDAP authentication, the user names take the form of *First* *Last* and this format should be used in the Helm chart to define these users.
```{yaml}
hub:
  config:
    JupyterHub:
      admin_access: true
    Authenticator:
      admin_users:
        - Bryan Jonas
```

## Login Page Announcement
In order to aid users in understanding how to log in to the system, we added an announcement at the top of the log in page. You can also make these announcement on the spark, home, and logout page in a similar manner.
```{yaml}
hub:
  config:
    JupyterHub:
      template_vars:
        announcement_login: Please log in with EECSNet credentials (first.last).
```

## LDAP Authentication
We worked with LTC Morrell to get this LDAP Authentication established to remove the burden of managing user acccounts. One future change will be to utilize a seperate service account to search the Active Directory (instead of the bryan.jonas@eecs.net account).
```{yaml}
config:
    JupyterHub:
      authenticator_class: ldapauthenticator.LDAPAuthenticator
    LDAPAuthenticator:
      bind_dn_template:
        - 'cn={username},ou=Faculty,dc=eecs,dc=net'
        - 'cn={username},ou=Cadets,dc=eecs,dc=net'
      lookup_dn: true
      lookup_dn_search_filter: '({login_attr}={login})'
      lookup_dn_search_password: PASSWORD!!!!
      lookup_dn_search_user: bryan.jonas@eecs.net
      lookup_dn_user_dn_attribute: cn
      server_address: dc01.eecs.net
      user_attribute: sAMAccountName
      user_search_base: 'dc=eecs,dc=net'
```