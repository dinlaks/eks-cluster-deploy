# EKS Cluster using AWS Cloud Formation Stack Template



1. Use cloudformation yaml manifest to create a stack for EKS cluster using aws cloud formation service
2. Once stack is ready, apply the acs-jam-c9-prep-summit.sh script.
3. Please use AWS Cloud9 console to apply the script and as well using kubetcl commands against EKS cluster

## Add EKS cluster as secured cluster services in ACS
To add EKS cluster in ACS, use helm install command to install the secured cluster services 

### Example: 
helm install -n stackrox --create-namespace \
    stackrox-secured-cluster-services rhacs/secured-cluster-services \
    -f <name_of_cluster_init_bundle.yaml> \
    --set clusterName=<name_of_the_secured_cluster> \
    --set centralEndpoint=acs.domain.com:443 \
    --set scanner.disable=false \
    --set imagePullSecrets.username=<username> \
    --set imagePullSecrets.password=<password>

Using Cluster Registration Secrets:

helm install -n stackrox --create-namespace \
    stackrox-secured-cluster-services rhacs/secured-cluster-services \
    --set-file crs.file=<crs_file_name.yaml> \
    --set clusterName=<name_of_the_secured_cluster> \
    --set centralEndpoint=<endpoint_of_central_service> \
    --set scanner.disable=false \
    --set imagePullSecrets.username=<username> \
    --set imagePullSecrets.password=<password>  # red hat account credentials 


## Add EKS cluster as managedcluster to ACM
To add EKS cluster in ACM, do the following; 

1. Create a secret
```bash
oc create secret generic pull-secret -n open-cluster-management --from-file=.dockerconfigjson=<path-to-pull-secret> --type=kubernetes.io/dockerconfigjson
```
2. A defined **_multiclusterhub.spec.imagePullSecret_** if you are importing a cluster that was not created by OpenShift Container Platform
```bash
oc edit multiclusterhub -n open-cluster-management -o yaml 

spec:
  availabilityConfig: High
  enableClusterBackup: false
  imagePullSecret: pull-secret
  ingress: {}
  overrides:
    components:
    - configOverrides: {}
      enabled: true
      name: app-lifecycle
```

**_NOTE_** : If required, please add the pull-secret to **_multicluster-engine_** namespace and ensure imagePullSecret is added to multiclusterengine resource. 
```bash
oc edit multiclusterengine -o yaml

spec:
  availabilityConfig: High
  imagePullSecret: pull-secret
  overrides:
    components:
    - configOverrides: {}
      enabled: true
      name: local-cluster
    - configOverrides: {}
      enabled: true
```

3. Import cluster using ACM GUI and generate a command and run against a target eks cluster. 

