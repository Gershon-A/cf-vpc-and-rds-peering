
#!/bin/bash
# a script that create a VPC peering between VPC and RDS.
set -e # exit on error

# Helper functions
echoerr() { 
    tput bold;
    tput setaf 1;
    echo "$@";
    tput sgr0; 1>&2; }

# Define Directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Build the image
docker build . \
 -t aws-tools \
 -f  Dockerfile

print_usage() {
    echo "a script that create a VPC peering between VPC and RDS:"
    echo "  -h  |--help                - Show usage information"
    echo "  -e= |--env=                - Target environment (dev, prd)"
    echo "  -c= |--stack-name=         - STACK_NAME Name (e.g VPC-Peering)"
    echo "  -r= |--default-region=     - region for cluster deployment (e.g us-east-1)"
    echo "  -rc=|--requester-vpc-id=   - VPC ID of the EKS cluster - "REQUESTER""
    echo "  -ac=|--accepter-vpc-id=    - VPC ID of the RDS cluster - "ACCEPTER""
    echo "  -f|--force                 - Force the operation (don't wait for user input)"
    echo ""
    echo "TIP:to get all avaliable VPC's \
    [docker run --rm -v "$HOME\.aws\credentials":/root/.aws/credentials:ro \
     aws-tools \
     aws ec2 describe-vpcs --filters Name=tag-key,Values=* Name=tag-value,Values=* --output text --region us-east-1]"
    echo "On Windows, we must to use full path to directory, set it [export MYPATH=\"C:\\Users\\xxxxxxx\\Documents\\Project\\CloudFormation\\eks-cluster\"]"
    echo "On Windows, we also must set HOME directory in windows style: [export HOME=\"C:\\Users\\xxxxx\"]"
    echo "Example usage: ./$(basename $0) -e=dev -c=VPC-Peering -r=us-east-1 -rc=vpc-0a4ba7103a0f2c5db -ac=vpc-0e640bc09a7f32f8c"
}
# Parse command line arguments
for i in "$@"
do
case $i in
    -h|--help)
    print_usage
    exit 0
    ;;
    -e=*|--env=*)
    STACK_ENV="${i#*=}"
    shift # past argument=value
    ;;
    -c=*|--stack-name=*)
    STACK_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -r=*|--default-region=*)
    STACK_REGION="${i#*=}"
    shift # past argument=value
    ;;
    -rc=*|--requester-vpc-id=*)
    REQUESTER_VPC_ID="${i#*=}"
    shift # past argument=value
    ;;
    -ac=*|--accepter-vpc-id=*)
    ACCEPTER_VPC_ID="${i#*=}"
    shift # past argument=value
    ;;
    -f|--force)
    FORCE=1
    ;;
    *)
    echoerr "ERROR: Unknown argument"
    print_usage
    exit 1
    # unknown option
    ;;
esac
done
### Print total arguments and their values

# echo "All Arguments values:" $@
echo "provided STACK_ENV: " ${STACK_ENV}
echo "provided STACK_NAME: " ${STACK_NAME} 
echo "provided RDS_CLUSTER_REGION: " ${STACK_REGION}
echo "provided REQUESTER_VPC_ID: " ${REQUESTER_VPC_ID} 
echo "provided ACCEPTER_VPC_ID: " ${ACCEPTER_VPC_ID}

# Validate mandatory input
if [ -z "$MYPATH" ]; then
    echoerr "Error: local path is not set"
    print_usage
    exit 1
fi
if [ -z "$HOME" ]; then
    echoerr "Error: HOME path is not set"
    print_usage
    exit 1
fi
if [ -z "${STACK_ENV}" ]; then
    echoerr "Target environment not selected!"
    print_usage
    exit 1
elif [[ "${STACK_ENV}" != "dev" && "${STACK_ENV}" != "stg" && "${STACK_ENV}" != "prd" ]]; then
    echoerr "Unsupported environment: ${STACK_ENV}"
    print_usage
    exit 1
fi


### Prepare VPC PEERING stack deploymnet 
STACK_NAME="${STACK_NAME^^}-${STACK_ENV^^}"
STACK_TEMPLATE="/templates/stage2-peer-2-vpc.yaml"

# recreate the container with the configuration directory contains setup files and aws credentials.
CONTAINER_ID=$(\
docker run  \
  -v "$HOME\.aws\credentials":/root/.aws/credentials:ro \
  -v "$MYPATH/vpc-peering/templates":/templates \
  -t -d aws-tools \
  ) &&  echo "Container running with id: $CONTAINER_ID"

# Copy the template file to docker container
docker cp templates/. $CONTAINER_ID:/templates

# Validating
echo "Validating Cloud formation VPC peering stack template (executed on docker)..."
docker exec -it $CONTAINER_ID sh \
-c "aws cloudformation validate-template --template-body  file://${STACK_TEMPLATE} --region ${STACK_REGION}"  1> /dev/null
[ $? -eq 0 ] || { echoerr "Stack validation failed!"; exit 1; }

# Set variables required to peering 

## Get VPC ID of acceptor i.e. RDS
echo "getting the  CIDR of acceptor (RDS instance)"
ACCEPTER_CIDR=$(docker exec  -ti $CONTAINER_ID aws ec2 describe-vpcs --vpc-ids ${ACCEPTER_VPC_ID} --query=Vpcs[0].CidrBlockAssociationSet[0].CidrBlock --output text --region ${STACK_REGION})
echo "Accepter cidr = $ACCEPTER_CIDR"

## Get VPC ID of requestor i.e. EKS 
echo "getting the  CIDR of requester (EKS cluster)"
REQUESTER_CIDR=$(docker exec  -ti $CONTAINER_ID aws ec2 describe-vpcs --vpc-ids ${REQUESTER_VPC_ID} --query=Vpcs[0].CidrBlockAssociationSet[0].CidrBlock --output text --region ${STACK_REGION})
echo "Requester cidr = $REQUESTER_CIDR"

## get Public Route table ID of requestor and acceptor
echo "get Public Route table ID of acceptor (RDS instance) "
ACCEPTER_ROUTE_ID=$(docker exec  -ti $CONTAINER_ID aws ec2 describe-route-tables --filters Name=vpc-id,Values=${ACCEPTER_VPC_ID} --query=RouteTables[0].RouteTableId --output text --region ${STACK_REGION})
echo "Accepter Route table ID = $ACCEPTER_ROUTE_ID"
echo "get Public Route table ID of requestor (EKS cluster) "
# !! We query cloudformation for "Public Route Table" name. We can have an issue if the name be changed in the future
REQUESTER_ROUTE_ID=$(docker exec  -ti $CONTAINER_ID aws ec2 describe-route-tables --filters Name="tag:aws:cloudformation:logical-id",Values="PublicRouteTable" --query=RouteTables[0].RouteTableId --output text --region ${STACK_REGION})
echo "Requester Route table ID = $REQUESTER_ROUTE_ID"

# Find the RDS VPC SECURITY GROUP ID
RDS_VPC_SECURITY_GROUP_ID=$(docker exec  -ti $CONTAINER_ID aws ec2 describe-security-groups --filters Name=vpc-id,Values=${ACCEPTER_VPC_ID} --query=SecurityGroups[0].GroupId --output text --region ${STACK_REGION})
echo "RDS_VPC_SECURITY_GROUP_ID is : $RDS_VPC_SECURITY_GROUP_ID"
# Deploy the stack
# echo "Deploying stack template (executed on docker)..."

COMMAND="
aws cloudformation --region ${STACK_REGION} deploy \
  --stack-name ${STACK_NAME} \
  --template-file  ${STACK_TEMPLATE}\
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
        RDSServiceVPC=${ACCEPTER_VPC_ID} EKSServiceVPC=${REQUESTER_VPC_ID} \
        RDSrouteTable=${ACCEPTER_ROUTE_ID} EKSrouteTable=${REQUESTER_ROUTE_ID} \
        RDSSecurityGroup=${RDS_VPC_SECURITY_GROUP_ID} 
"
echo "COMMAND=${COMMAND}"
docker exec -it $CONTAINER_ID sh \
-c "${COMMAND}"

## Find the Stack ID
STACK_ID=$(docker exec  -ti $CONTAINER_ID  aws cloudformation describe-stacks --region ${STACK_REGION} --stack-name ${STACK_NAME} | jq -r '.Stacks[].StackId')
#echo "STACK ID: $STACK_ID"
echo "Waiting on ${STACK_ID} create completion..."
docker exec -it $CONTAINER_ID sh \
-c "aws cloudformation --region ${STACK_REGION} wait stack-create-complete --stack-name ${STACK_ID};aws cloudformation --region ${STACK_REGION} describe-stacks --stack-name ${STACK_ID} | jq .Stacks[0].Parameters"


### If successful - return  Peering Connection ID
echo "Checking if Peering Connection successful created"
VPC_PEERING_ID=$(docker exec  -ti $CONTAINER_ID aws cloudformation describe-stacks --region ${STACK_REGION} --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='AWSEC2VPCPeeringConnection'].OutputValue" --output text)  1> /dev/null
[ $? -eq 0 ] || { echoerr "Peering Connection failed!"; exit 1; }
echo "VPC_PEERING_ID is: $VPC_PEERING_ID"

# We are done - Removing container 
docker rm -f $CONTAINER_ID &>/dev/null && echo 'We are done - container removed'