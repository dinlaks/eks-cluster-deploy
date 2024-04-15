# ACS Challenge C9 Env Prep

echo "Setting up your Jam environment for the challenges!"

# for use with a lot of things
sudo yum -y -q install jq

# remove the temp user
aws cloud9 update-environment --environment-id $C9_PID --managed-credentials-action DISABLE

# install kubecetl
sudo curl --silent --location -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.28.5/2024-01-04/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl

# install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
# helm repo add rhacs https://mirror.openshift.com/pub/rhacs/charts/

# roxctl install
sudo curl --silent --location -o /usr/local/bin/roxctl https://mirror.openshift.com/pub/rhacs/assets/4.4.0/bin/linux/roxctl
sudo chmod +x /usr/local/bin/roxctl

# install oc
sudo curl --silent --location -o /tmp/openshift-client-linux.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
sudo tar -xf  /tmp/openshift-client-linux.tar.gz  -C /tmp/
sudo cp /tmp/oc /usr/local/bin/

# Set AWS region in env and awscli config
AWS_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
echo "export AWS_DEFAULT_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
echo "AWS Region: $AWS_REGION" >> candleco.txt

# Set accountID
ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "AWS Account ID: $ACCOUNT_ID" >> candleco.txt

# Set EKS cluster name
EKS_CLUSTER_NAME=$(aws eks list-clusters --region ${AWS_REGION} --query clusters --output text)
echo "export EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME}" | tee -a ~/.bash_profile
echo "export CLUSTER_NAME=${EKS_CLUSTER_NAME}" | tee -a ~/.bash_profile
echo "EKS Cluster: $EKS_CLUSTER_NAME" >> candleco.txt

# Update kubeconfig and set cluster-related variables if an EKS cluster exists

if [[ "${EKS_CLUSTER_NAME}" != "" ]]
then

# Update kube config
    aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}

# Set EKS node group name
    EKS_NODEGROUP=$(aws eks list-nodegroups --cluster ${EKS_CLUSTER_NAME} --region ${AWS_REGION} | jq -r '.nodegroups[0]')
    echo "export EKS_NODEGROUP=${EKS_NODEGROUP}" | tee -a ~/.bash_profile

# Set EKS nodegroup worker node instance profile
    ROLE_NAME=$(aws eks describe-nodegroup --cluster-name $EKS_CLUSTER_NAME --nodegroup-name ${EKS_NODEGROUP} --region ${AWS_REGION} --query 'nodegroup.nodeRole' --output text)
    echo "export ROLE_NAME=${ROLE_NAME}" | tee -a ~/.bash_profile

elif [[ "${EKS_CLUSTER_NAME}" = "" ]]
then

# Print a message if there's no EKS cluster
   echo "There are no EKS clusters provisioned in region: ${AWS_REGION}"

fi

# deploy the candleco app using the repos built into the environment.

IMAGEREPOURI=`aws ecr describe-repositories --query "repositories[].[repositoryUri]" --output text | awk '/candleco-images/{ print $0 }'`
WEBREPOURI=`aws ecr describe-repositories --query "repositories[].[repositoryUri]" --output text | awk '/candleco-web/{ print $0 }'`
DBREPOURI=`aws ecr describe-repositories --query "repositories[].[repositoryUri]" --output text | awk '/candleco-db/{ print $0 }'`
OSREPOURI=`aws ecr describe-repositories --query "repositories[].[repositoryUri]" --output text | awk '/candleco-db/{ print $0 }'`

mkdir deployments

cat <<EOF > deployments/candleco-images-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: candleco-images-deployment
  namespace: candleco
  labels:
    app: candleco-images
spec:
  replicas: 1
  selector:
    matchLabels:
      app: candleco-images
  template:
    metadata:
      labels:
        app: candleco-images
    spec:
      containers:
      - name: candleco-images
        image: $IMAGEREPOURI:latest
      restartPolicy: Always
EOF

cat <<EOF > deployments/candleco-web-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: candleco-web-deployment
  namespace: candleco
  labels:
    app: candleco-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: candleco-web
  template:
    metadata:
      labels:
        app: candleco-web
    spec:
      containers:
      - name: candleco-web
        image: $WEBREPOURI:latest
      restartPolicy: Always
EOF

cat <<EOF > deployments/candleco-db-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: candleco-db-deployment
  namespace: candleco
  labels:
    app: candleco-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: candleco-db
  template:
    metadata:
      labels:
        app: candleco-db
    spec:
      containers:
      - name: candleco-db
        image: $DBREPOURI:latest
      restartPolicy: Always
EOF

cat <<EOF > deployments/candleco-os-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: candleco-os-deployment
  namespace: candleco
  labels:
    app: candleco-os
spec:
  replicas: 1
  selector:
    matchLabels:
      app: candleco-os
  template:
    metadata:
      labels:
        app: candleco-os
    spec:
      containers:
      - name: candleco-os
        image: $OSREPOURI:latest
      restartPolicy: Always
EOF

kubectl create namespace candleco

kubectl apply -f deployments/candleco-images-deployment.yaml  -n candleco
kubectl apply -f deployments/candleco-web-deployment.yaml  -n candleco
kubectl apply -f deployments/candleco-db-deployment.yaml  -n candleco
kubectl apply -f deployments/candleco-os-deployment.yaml  -n candleco

source ~/.bash_profile

# create an override for ACS Sensor to suit Jam environment to be used with helm deployment

cat <<EOF >sensor-jam.yaml
  sensor:
    resources:
      requests:
        cpu: "1"
        memory: "2Gi"
      limits:
        cpu: "1"
        memory: "4Gi"
EOF

S3BUCKET=`aws s3api list-buckets --output text | awk -F ' ' '/candleco/{ print $3 }'`

echo "S3 Bucket: $S3BUCKET" >> candleco.txt

echo "export S3BUCKET=${S3BUCKET}" | tee -a ~/.bash_profile
