# EKS Cluster using AWS Cloud Formation Stack Template



1. Use cloudformation yaml manifest to create a stack for EKS cluster using aws cloud formation service
2. Once stack is ready, apply the acs-jam-c9-prep-summit.sh script.

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
