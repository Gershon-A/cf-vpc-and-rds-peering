# cf-vpc-and-rds-peering
1. Create docker image with some usefull tolls (aws-iam-authenticator ,awscli,jq)
```
docker build . \
 -t aws-tools \
 -f  Dockerfile
 ```
## Usage
- Setup full path to working directory and home
`export MYPATH="C:\Users\xxxxx\Documents\Project\cf-vpc-and-rds-peering"`
`export HOME="C:\Users\XXXXXX"`
- run `peering.sh -e=dev -c=VPC-Peering -r=us-east-1 -rc=vpc-0a4ba7103a0f2c5db -ac=vpc-0e640bc09a7f32f8c`
- to get all avaliable VPC's run container as `docker run --rm -v "$HOME\.aws\credentials":/root/.aws/credentials:ro  testproject-aws-tools aws ec2 describe-vpcs --filters Name=tag-key,Values=* Name=tag-value,Values=* --output text --region us-east-1`
look for a tag name [eksctl-XXXX] for EKS cluster and [XXX-RDS] for MySql Rds
- Note the VPC's ID's 


## ToDo
1. In the template:
- Get and map EKSrouteTable, RDSrouteTable, RDSSecurityGroup automaticaly
