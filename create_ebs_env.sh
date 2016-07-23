#!/usr/bin/env bash

# requires: pip install awscli awsebcli

# uncomment to debug
#set -x

fail() {
    echo configuration failed
    exit 1
}

export AWS_DEFAULT_REGION=us-east-1

datetag=$(date +%Y%m%d%H%M)
identifier=deployer$datetag
mkdir -p tmp/$identifier

echo "Creating EBS application $identifier"

# Find the ID of the default VPC
aws ec2 describe-vpcs --filters Name=isDefault,Values=true > tmp/$identifier/defaultvpc.json || fail
vpcid=$(jq -r '.Vpcs[0].VpcId' tmp/$identifier/defaultvpc.json)
echo "default vpc is $vpcid"

# Create an elasticbeantalk application
aws elasticbeanstalk create-application \
    --application-name $identifier \
    --description "deployer $env $datetag" > tmp/$identifier/ebcreateapp.json || fail
echo "ElasticBeanTalk application created"

# Get the name of the latest Docker solution stack
dockerstack="$(aws elasticbeanstalk list-available-solution-stacks | \
    jq -r '.SolutionStacks[]' | grep -P '.+Amazon Linux.+Docker.+' | head -1)"

# Create the EB API environment
sed "s/POSTGRESPASSREPLACEME/$dbpass/" ebs-options.json > tmp/$identifier/ebs-options.json || fail
sed -i "s/POSTGRESHOSTREPLACEME/$dbhost/" tmp/$identifier/ebs-options.json || fail
aws elasticbeanstalk create-environment \
    --application-name $identifier \
    --environment-name deployer-api \
    --description "deployer API environment" \
    --tags "Key=Owner,Value=$(whoami)" \
    --solution-stack-name "$dockerstack" \
    --tier "Name=WebServer,Type=Standard,Version=''" > tmp/$identifier/ebcreateapienv.json || fail
apieid=$(jq -r '.EnvironmentId' tmp/$identifier/ebcreateapienv.json)
echo "API environment $apieid is being created"

# Upload the application version
aws s3 mb s3://$identifier
aws s3 cp ebs.json s3://$identifier/
aws elasticbeanstalk create-application-version \
    --application-name "$identifier" \
    --version-label deployer-api \
    --source-bundle "S3Bucket=$identifier,S3Key=ebs.json" > tmp/$identifier/appversion.json

# Wait for the environment to be ready (green)
echo -n "waiting for environment"
while true; do
    aws elasticbeanstalk describe-environments --environment-id $apieid > tmp/$identifier/$apieid.json
    health="$(jq -r '.Environments[0].Health' tmp/$identifier/$apieid.json)"
    if [ "$health" == "Green" ]; then break; fi
    echo -n '.'
    sleep 10
done
echo

# Deploy the docker container to the instances
aws elasticbeanstalk update-environment \
    --application-name $identifier \
    --environment-id $apieid \
    --version-label deployer-api > tmp/$identifier/$apieid.json

url="$(jq -r '.CNAME' tmp/$identifier/$apieid.json)"
echo "Environment is being deployed. Public endpoint is http://$url"
