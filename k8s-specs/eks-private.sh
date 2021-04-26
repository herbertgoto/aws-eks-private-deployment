#!/bin/bash -ex

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d\" -f4)
export AZS=($(aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output text --region $AWS_REGION))

echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
echo "export AZS=(${AZS[@]})" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region

aws kms create-alias --alias-name alias/privateeks --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
export EKS_CMK=$(aws kms describe-key --key-id alias/privateeks --query KeyMetadata.Arn --output text)
echo "export EKS_CMK=${EKS_CMK}" | tee -a ~/.bash_profile

export CLUSTER_NAME=<Enter the name for the EKS cluster>
export K8S_VERSION='"<Enter the version of Kubernetes for your cluster>"'

echo "export CLUSTER_NAME=${CLUSTER_NAME}" | tee -a ~/.bash_profile
echo "export K8S_VERSION=${K8S_VERSION}" | tee -a ~/.bash_profile

cat << EOF > eks-private-with-oidc.yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  version: ${K8S_VERSION}

availabilityZones: ["${AZS[0]}", "${AZS[1]}", "${AZS[2]}"]

privateCluster:
  enabled: true
  additionalEndpointServices:
  # For Cluster Autoscaler
  - "autoscaling"
  # For creating node groups
  - "cloudformation"
  # CloudWatch logging
  - "logs"
      
# CMK for the EKS cluster to use when encrypting your Kubernetes secrets
secretsEncryption:
  keyARN: ${EKS_CMK}
cloudWatch:
    clusterLogging:
        # enable specific types of cluster control plane logs
        enableTypes: ["*"] # ["api", "scheduler", "controllerManager"]
# Enable IAM OIDC Provider and create sa for AWS Load Balancer Controller
iam: 
  withOIDC: true
  serviceAccounts:
  - metadata:
      name: aws-load-balancer-controller
      namespace: kube-system
    wellKnownPolicies:
      awsLoadBalancerController: true
EOF

eksctl create cluster -f eks-private-with-oidc.yaml