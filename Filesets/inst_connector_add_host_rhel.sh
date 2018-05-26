#!/bin/bash
#
# Title:    inst_connector_add_host_rhel.sh
# Summary:  Installs the Rubrik Connector software, adds the host to the Rubrik cluster, and
#           protects a fileset for a CentOS/RHEL based host.
#           Note: uses the hostname of the running machine, so this must be resolvable in DNS
#           for the Rubrik cluster.
# Author:   Tim Hynes, DevOps SE, tim.hynes@rubrik.com
#
RUBRIK_HOST='rubrik.demo.com'
RUBRIK_USER='admin'
RUBRIK_PASS='NotAP@ss!'
FILESET_NAME='mynewfileset'
SLA_DOMAIN='Bronze'
# Download and install Rubrik Backup Service
curl -LOks "https://$RUBRIK_HOST/connector/rubrik-agent.x86_64.rpm"
sudo rpm -i rubrik-agent.x86_64.rpm
# Add host to Rubrik cluster
ADD_HOST=$(curl -k -s \
    -u "$RUBRIK_USER:$RUBRIK_PASS" \
    --header 'Content-Type':'application/json' \
    --header 'Accept':'application/json' \
    -X POST https://$RUBRIK_HOST/api/v1/host \
    -d "{\"hostname\":\"$HOSTNAME\",\"hasAgent\":true}")
MY_HOST_ID=$(echo $ADD_HOST | jq -r '.id')
if [ $MY_HOST_ID == 'null' ]; then
    echo $(echo $ADD_HOST | jq -r '.message')
    echo "Something went wrong adding the host to the Rubrik system, exiting"
    exit 1
fi
# Add fileset to host
## Get the fileset template
FILESET_TEMPLATES=$(curl -k -s \
    -u "$RUBRIK_USER:$RUBRIK_PASS" \
    --header 'Accept':'application/json' \
    -X GET https://$RUBRIK_HOST/api/v1/fileset_template?primary_cluster_id=local)
MY_FILESET_TEMPLATE=$(echo $FILESET_TEMPLATES | jq -c ".data[] | select(.name==\"$FILESET_NAME\")" | jq -r '.id')
if [ -z $MY_FILESET_TEMPLATE ]; then
    echo "Fileset Template $FILESET_NAME not found on Rubrik system, exiting"
    exit 1
fi
## Create the fileset
NEW_FILESET=$(curl -k -s \
    -u "$RUBRIK_USER:$RUBRIK_PASS" \
    --header 'Content-Type':'application/json' \
    --header 'Accept':'application/json' \
    -X POST https://$RUBRIK_HOST/api/v1/fileset \
    -d "{\"hostId\": \"$MY_HOST_ID\",\"templateId\": \"$MY_FILESET_TEMPLATE\"}")
MY_FILESET_ID=$(echo $NEW_FILESET | jq -r '.id')
if [ $MY_FILESET_ID == 'null' ]; then
    echo $(echo $NEW_FILESET | jq -r '.message')
    echo "Something went wrong creating the fileset, exiting"
    exit 1
fi
# Protect fileset
## Get SLA Domain ID
SLA_DOMAINS=$(curl -k -s \
    -u "$RUBRIK_USER:$RUBRIK_PASS" \
    -X GET https://$RUBRIK_HOST/api/v1/sla_domain?primary_cluster_id=local)
MY_SLA_DOMAIN=$(echo $SLA_DOMAINS | jq -c ".data[] | select(.name==\"$SLA_DOMAIN\")" | jq -r '.id')
if [ -z $MY_SLA_DOMAIN ]; then
    echo "SLA Domain $SLA_DOMAIN not found on Rubrik system, exiting"
    exit 1
fi
## Add SLA domain to fileset
PROTECT_FILESET=$(curl -k -s \
    -u "$RUBRIK_USER:$RUBRIK_PASS" \
    --header 'Content-Type':'application/json' \
    -X PATCH https://$RUBRIK_HOST/api/v1/fileset/$MY_FILESET_ID \
    -d "{\"configuredSlaDomainId\":\"$MY_SLA_DOMAIN\"}")
echo "Fileset created and protected, exiting"
exit 0
