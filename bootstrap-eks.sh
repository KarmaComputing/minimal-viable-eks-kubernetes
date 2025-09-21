#!/bin/bash

set -exuo pipefail

export AWS_REGION=eu-west-2

echo 'Dry run first to show action'

confirm() {
  echo "Continue? y or ctl + c"
  read -N 1 REPLY
  echo
  if [[ "$REPLY" == "y" || "$REPLY" == "Y" ]]; then
    "$@"
  else
    echo "Cancelled"
    exit 1
  fi
}

eksctl create cluster --dry-run -f cluster.yaml
echo Proposing creating above eks cluster. Creation can take about 20 minutes... wowee
confirm

echo 'You can watch its creation progress at https://eu-west-2.console.aws.amazon.com/cloudformation/'
echo 'eventually the cluster will be visible in console at https://eu-west-2.console.aws.amazon.com/eks/clusters?region=eu-west-2'
#eksctl create cluster --name=test-eks --enable-auto-mode

echo 'see wellKnownPolicies in https://docs.aws.amazon.com/eks/latest/eksctl/iamserviceaccounts.html'
eksctl create cluster -f cluster.yaml

echo 'enabling eks-pod-identity-agent for EKS Pod Identity Associations'
echo 'See https://docs.aws.amazon.com/eks/latest/eksctl/pod-identity-associations.html'

# "You do not need to install the EKS Pod Identity Agent on EKS Auto Mode Clusters"
# See https://docs.aws.amazon.com/eks/latest/userguide/pod-id-agent-setup.html
eksctl create addon --cluster test-eks --name eks-pod-identity-agent

echo 'Now read/consider driver installation (not needed?) https://aws.amazon.com/blogs/containers/introducing-efs-csi-dynamic-provisioning/'


echo 'docs: https://github.com/kubernetes-sigs/aws-efs-csi-driver?tab=readme-ov-file#deploy-the-driver'
echo 'docs: https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html'
echo 'docs: https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html#:~:text=AWS%20Console).-,If%20using%20IAM%20roles%20for%20service%20accounts,-View%20your%20cluster%E2%80%99s'

export cluster_name=test-eks
export role_name=AmazonEKS_EFS_CSI_DriverRole
export aws_account_id=$(aws sts get-caller-identity | jq -r '.Account')
oidc_address=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | sed 's#https://##g')

cat > aws-efs-csi-driver-trust-policy.json <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$aws_account_id:oidc-provider/$oidc_address"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "$oidc_address:sub": "system:serviceaccount:kube-system:efs-csi-*",
          "$oidc_address:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOT

set +e
aws iam create-role \
  --role-name $role_name \
  --assume-role-policy-document file://"aws-efs-csi-driver-trust-policy.json"
set -e

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
  --role-name $role_name


echo 'Did we miss the service account creation?'
echo 'https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html#:~:text=service%2Drole/AmazonEFSCSIDriverPolicy-,If%20using%20IAM%20roles%20for%20service%20accounts,-Run%20the%20following'

eksctl utils describe-addon-versions --kubernetes-version 1.32 --name aws-efs-csi-driver | grep AddonVersion

eksctl create addon --cluster $cluster_name --name aws-efs-csi-driver --version v2.1.11-eksbuild.1 \
    --service-account-role-arn arn:aws:iam::$aws_account_id:role/$role_name --force

echo 'now testing pv pvc stuff'

vpc_id=$(aws eks describe-cluster \
    --name $cluster_name \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)


cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids $vpc_id \
    --query "Vpcs[].CidrBlock" \
    --output text \
    --region $AWS_REGION)


security_group_id=$(aws ec2 create-security-group \
    --group-name MyEfsSecurityGroup \
    --description "My EFS security group" \
    --vpc-id $vpc_id \
    --output text)

if [ $? -ne 0 ]; then
    echo "Security group may already exist, getting its id by name"
    security_group_id=$(aws ec2 describe-security-groups   --filters Name=group-name,Values=MyEfsSecurityGroup | jq -r '.SecurityGroups[0].GroupId')
fi

security_group_id=$(echo $security_group_id | sed 's/ .*//g')

aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --protocol tcp \
    --port 2049 \
    --cidr $cidr_range

file_system_id=$(aws efs create-file-system \
    --region $AWS_REGION \
    --performance-mode generalPurpose \
    --query 'FileSystemId' \
    --output text)

# automated:
# https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/efs-create-filesystem.md#:~:text=Create%20mount%20targets.
kubectl get nodes -o json | jq '.items[].metadata.annotations["alpha.kubernetes.io/provided-node-ip"]'

# Automated: apply mount target to all subnets since auto mode may place nodes in
# subnets not yet containing a node...
#

subnet_ids=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].{SubnetId: SubnetId,AvailabilityZone: AvailabilityZone,CidrBlock: CidrBlock}' --output json | jq -r '.[].SubnetId')

# TODO security/harden check
set +e
for subnet_id in $subnet_ids; do
  aws efs create-mount-target \
    --file-system-id $file_system_id \
    --subnet-id $subnet_id \
    --security-groups $security_group_id
done
set -e

# TODO drop this, subnet_ids loop deprecates it
#set +e
# node_ips=$(kubectl get nodes -o json | jq -r '.items[].metadata.annotations["alpha.kubernetes.io/provided-node-ip"]')
#for node_ip in $node_ips; do
#  subnet_id=$(aws ec2 describe-network-interfaces \
#    --filters "Name=addresses.private-ip-address,Values=$node_ip" \
#    --query "NetworkInterfaces[0].SubnetId" \
#    --output text)
#
#  aws efs create-mount-target \
#    --file-system-id $file_system_id \
#    --subnet-id $subnet_id \
#    --security-groups $security_group_id
#done
#set -e

# Not needed in EKS auto clusters
#echo 'Verifying existance of EKS Pod Identity Agent pods'
#kubectl get pods -n kube-system | grep 'eks-pod-identity-agent'

echo 'now testing storage driver https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/README.md#examples'
echo 'Verifying storage'
echo 'based on https://github.com/kubernetes-sigs/aws-efs-csi-driver/tree/master/examples/kubernetes/static_provisioning/specs'
kubectl apply -f storageclass.yaml
echo "Updating pv.yaml with file_system_id $file_system_id"
sed -i "s/volumeHandle:.*/volumeHandle: $file_system_id/g" pv.yaml
kubectl apply -f pv.yaml
kubectl get pv
kubectl apply -f pvc.yaml
kubectl get pvc
kubectl apply -f pod-using-pvc.yaml
kubectl get pod

echo 
echo 'You should now configure your cli to use aws (ACCESS_TOKEN or sso etc)'
echo 'Then, if you can now `kubectl get nodes`, your EKS cluster is good.'
echo
echo 'Now to setup ingress, read https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html'

echo 'How do I enable cloudwatch logging?'
echo 'Answer: with eksctl utils update-cluster-logging --enable-types={SPECIFY-YOUR-LOG-TYPES-HERE (e.g. all)} --region=eu-west-2 --cluster=test-eks'

echo 'Want custom nodeclass / nodepools?'
echo 'see https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html'
echo 'see https://docs.aws.amazon.com/eks/latest/userguide/create-node-pool.html'

echo 'You can verify storage by tailing the test storage pod like so:'
echo 'kubectl exec -ti efs-app -- tail /data/out.txt'
