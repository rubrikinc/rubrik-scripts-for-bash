#!/bin/bash
#
# Title:    create_fileset_and_snapshot.sh
# Summary:  Checks a Rubrik cluster to see if a fileset already exists for
#           the passed parameters, if it does then it will take an on-demand
#           snapshot, waiting for the snapshot to finish before returning. If the
#           fileset does not exist then it will create it.
# Author:   Tim Hynes, DevOps SE, tim.hynes@rubrik.com
#
# ===============
# Variables
RUBRIK_IP='demo.rubrik.com'
RUBRIK_USER='admin'
RUBRIK_PASS='NotAP@ss!'
HOST_NAME='myhost.rubrik.com'
FOLDER_PATH='/mydata'
SLA_DOMAIN='Bronze'
# ===============
# get auth token
TOKEN="Bearer $(curl -k -s -u "$RUBRIK_USER:$RUBRIK_PASS" -X POST https://$RUBRIK_IP/api/v1/session | jq -r '.token')"
# check that host exists
HOST_QUERY=$(curl -k -s --header "Authorization: $TOKEN" -X GET https://$RUBRIK_IP/api/v1/host?hostname=$HOST_NAME)
if [ $(echo $HOST_QUERY | jq -r '.total') != '1' ]; then
    echo "Host $HOST_NAME not found on Rubrik system, exiting"
    exit 1
fi
MY_HOST_ID=$(echo $HOST_QUERY | jq -r '.data[0].id')
# check that fileset template exists
FILESET_TEMPLATES=$(curl -k -s --header "Authorization: $TOKEN" -X GET https://$RUBRIK_IP/api/v1/fileset_template)
MY_FILESET_TEMPLATE=$(echo $FILESET_TEMPLATES | jq -c ".data[] | select(.includes[]==\"$FOLDER_PATH\")" | jq -r '.id')
# create fileset template if it does not exist
if [ -z $MY_FILESET_TEMPLATE ]; then
    echo "Fileset Template not found, creating..."
    NEW_FILESET_TEMPLATE=$(curl -k -s \
        --header "Authorization: $TOKEN" \
        --header 'Content-Type':'application/json' \
        --header 'Accept':'application/json' \
        -X POST https://$RUBRIK_IP/api/v1/fileset_template \
        -d "{\"name\":\"$HOST_NAME : $FOLDER_PATH\",\"includes\":[\"$FOLDER_PATH\"],\"operatingSystemType\":\"Linux\"}"
        )
    MY_FILESET_TEMPLATE=$(echo $NEW_FILESET_TEMPLATE | jq -r '.id')
else
    echo "Fileset Template found"
fi
# check that fileset exists
MY_FILESET=$(curl -k -s --header "Authorization: $TOKEN" -X GET \
    "https://$RUBRIK_IP/api/v1/fileset?host_id=$MY_HOST_ID&template_id=$MY_FILESET_TEMPLATE" | jq -r '.data[0].id')
if [ $MY_FILESET == 'null' ]; then
    echo "Fileset not found, creating..."
    NEW_FILESET=$(curl -k -s \
        --header "Authorization: $TOKEN" \
        --header 'Content-Type':'application/json' \
        --header 'Accept':'application/json' \
        -X POST https://$RUBRIK_IP/api/v1/fileset \
        -d "{\"hostId\": \"$MY_HOST_ID\",\"templateId\": \"$MY_FILESET_TEMPLATE\"}"
        )
    MY_FILESET=$(echo $NEW_FILESET | jq -r '.id')
else
    echo "Fileset found"
fi
# take on-demand snapshot
SLA_DOMAINS=$(curl -k -s --header "Authorization: $TOKEN" -X GET https://$RUBRIK_IP/api/v1/sla_domain)
MY_SLA_DOMAIN=$(echo $SLA_DOMAINS | jq -c ".data[] | select(.name==\"$SLA_DOMAIN\")" | jq -r '.id')
if [ -z $MY_SLA_DOMAIN ]; then
    echo "SLA Domain $SLA_DOMAIN not found on Rubrik system, exiting"
    exit 1
fi
SNAPSHOT_REQ=$(curl -k -s \
    --header "Authorization: $TOKEN" -X POST \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/json' \
    "https://$RUBRIK_IP/api/v1/fileset/$MY_FILESET/snapshot" \
    -d "{\"slaId\":\"$MY_SLA_DOMAIN\"}")
SNAPSHOT_URL=$(echo $SNAPSHOT_REQ | jq -r '.links[0].href')
SNAPSHOT_STATUS=$(echo $SNAPSHOT_REQ | jq -r '.status')
while [ $SNAPSHOT_STATUS != 'SUCCEEDED' ] && [ $SNAPSHOT_STATUS != 'FAILED' ]
do
    echo "Snapshot status is $SNAPSHOT_STATUS, sleeping..."
    sleep 5
    SNAPSHOT_STATUS=$(curl -k -s \
        --header "Authorization: $TOKEN" -X GET \
        $SNAPSHOT_URL | jq -r '.status')
done
echo "Snapshot done"
exit 0
