#!/bin/bash
#
# Title:    restore_fileset_file.sh
# Summary:  Restores a file from a fileset backup on a Linux host.
# Author:   Tim Hynes, DevOps SE, tim.hynes@rubrik.com
#
# REQUIREMENTS:
#   - jq is required to parse export channel details
#
# Start of variables
CLUSTER='demo.rubrik.com'
USERNAME='admin'
PASSWORD='Not@Pa55!'
FILE='/home/ubuntu/importantfile'
FILESET_ID='3c870458-293d-4376-af5f-3f8da7cddd77'
# End of variables
FILESET_URI="https://$CLUSTER/api/v1/fileset/Fileset%3A%3A%3A$FILESET_ID"
# Get the latest snapshot, this could be refined if needed
SNAPSHOT_ID=$(curl -s -u "$USERNAME:$PASSWORD" -X GET --header 'Content-Type:application/json' -d '{}' $FILESET_URI -k -l | jq -r '.snapshots[0].id')
# Generate the URI for requesting the file download, and send the reuqest
DOWNLOAD_URI="https://$CLUSTER/api/v1/fileset/snapshot/$SNAPSHOT_ID/download_file"
REQUEST_URI=$(curl -s -u "$USERNAME:$PASSWORD" -X POST --header 'Content-Type:application/json' -d "{\"sourceDir\":\"$FILE\"}" $DOWNLOAD_URI -k -l | jq -r '.links[0].href')
# Grab the state of the request
REQUEST_DATA=$(curl -s -u "$USERNAME:$PASSWORD" -X GET --header 'Content-Type:application/json' -d '{}' $REQUEST_URI -k -l)
# If the request succeeded then crack on and get the file download link
if [ $(echo $REQUEST_DATA | jq -r '.status') = 'SUCCEEDED' ]
then
  echo "Request Succeeded"
  DOWNLOAD_URI=$(echo $REQUEST_DATA | jq -r '.links[1].href')
fi
# Pull down the file with no authentication
curl -LO https://$CLUSTER/$DOWNLOAD_URI -k
