# cf-vpc-and-rds-peering
1. Create docker image with some usefully tolls (aws-iam-authenticator ,awscli, jq)
```
docker build . \
 -t aws-tools \
 -f  Dockerfile
 ```
## Pre Requirements
AWS credentials was added to environment and located
`C:\Users\XXXXXX\.aws\credentials`
## Usage
- Setup full path to working directory and home (required for Windows)
`export MYPATH="C:\Users\xxxxx\Documents\Project\cf-vpc-and-rds-peering"`
`export HOME="C:\Users\XXXXXX"`
- For Linux
`export MYPATH=$PWD`
- Run `./peering.sh -h` for available options and flags.
- Example run `./peering.sh -e=dev -c=VPC-Peering -r=us-east-1 -rc=XXXXXXXX -ac=XXXXXXXX`
- to get all available VPC's run container as `docker run --rm -v "$HOME\.aws\credentials":/root/.aws/credentials:ro  aws-tools  aws ec2 describe-vpcs --filters Name=tag-key,Values=* Name=tag-value,Values=* --output text --region us-east-1`
look for a tag name [eksctl-XXXX] for EKS cluster and [XXX-RDS] for MySql Rds
- Note the VPC's ID's 
- Finally, this is how it looks like:
<img src="https://i.imgur.com/7lXoLO8.png"
     alt="Markdown Monster icon"
     style="float: left; margin-right: 10px;" />
## ToDo
1. In the template:
- Get and map EKSrouteTable, RDSrouteTable, RDSSecurityGroup automaticaly
2. Add AWS connection validation
