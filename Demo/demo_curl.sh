#!/bin/bash
#
# Title:    demo_curl.sh
# Summary:  Demonstrates interacting with the Rubrik REST API using curl.
# Author:   Tim Hynes, DevOps SE, tim.hynes@rubrik.com
#
# REQUIREMENTS:
#   - curl is required to interact with the API
#   - jq is required to parse JSON responses
#
RUBRIK_IP='rubrik.demo.com'
RUBRIK_USER='admin'
RUBRIK_PASS='NotAP@ss!'
# Standard REST call
curl -k -s -u "$RUBRIK_USER:$RUBRIK_PASS" -X GET 'https://$RUBRIK_IP/api/v1/cluster/me' | jq
# Get my VM
VM_NAME='myserver01'
curl -k -s -u "$RUBRIK_USER:$RUBRIK_PASS" -X GET "https://$RUBRIK_IP/api/v1/vmware/vm?name=$VM_NAME" | jq
# Store my VM ID as a variable
VM_ID=$(curl -k -s -u "$RUBRIK_USER:$RUBRIK_PASS" -X GET "https://$RUBRIK_IP/api/v1/vmware/vm?name=$VM_NAME" | jq -r '.data[0].id')
echo $VM_ID
# Get the Silver SLA domain
SLA_DOMAIN='Silver'
curl -k -s -u "$RUBRIK_USER:$RUBRIK_PASS" -X GET "https://$RUBRIK_IP/api/v1/sla_domain?name=$SLA_DOMAIN" | jq
# Store my SLA Domain ID as a variable
SLA_ID=$(curl -k -s -u "$RUBRIK_USER:$RUBRIK_PASS" -X GET "https://$RUBRIK_IP/api/v1/sla_domain?name=$SLA_DOMAIN" | jq -r '.data[0].id')
echo $SLA_ID
# Now we can post something, let's take an on-demand snapshot of our VM with the SLA domain we defined
PAYLOAD="{\"slaId\":\"$SLA_ID\"}"
echo $PAYLOAD | jq
# Let's create our snapshot
curl -k -s -u "$RUBRIK_USER:$RUBRIK_PASS" -X POST -d $PAYLOAD \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    "https://$RUBRIK_IP/api/v1/vmware/vm/$VM_ID/snapshot" | jq
# Let's try that again but this time we will keep the response
REQ_URL=$(curl -k -s -u "$RUBRIK_USER:$RUBRIK_PASS" -X POST -d $PAYLOAD \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    "https://$RUBRIK_IP/api/v1/vmware/vm/$VM_ID/snapshot" | jq -r '.links[0].href')
echo $REQ_URL
# Let's see what that URL returns with a GET request
watch -c "curl -k -s -u \"$RUBRIK_USER:$RUBRIK_PASS\" -X GET $REQ_URL | jq -C '.'"