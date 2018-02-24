#!/bin/bash
########################################################################################################
# Title:    on-demand-snapshot.sh
# Summary:  Create a On-Demand Snapshot
# Author:   Drew Russell - @drusse11
#
# REQUIREMENTS:
# jq is required to parse curl response. You can usually get the jq utility in the add on
# repository of most linux distros.
#
# The password can be passed as an option or entered on the command line.
#
# USAGE: ./on-demand-snapshot.sh -c 192.168.45.5 -u admin -p mypassword -v vsphere_vm_name
########################################################################################################

# Function to print the usage
usage() { echo "$0 [-c <IP_ADDRESS>] [-u <USERNAME>] [optional -p <PASSWORD> ] [-v <VM_NAME>]" 1>&2; exit 1; }
# Start of variables
# Read variables
while getopts c:u:p:v: option
do
 case "${option}"
 in
 c) CLUSTER=${OPTARG};;
 u) USERNAME=${OPTARG};;
 p) PASSWORD=${OPTARG};;
 v) VM_NAME=${OPTARG};;
 *) usage;;
 esac
done
shift $((OPTIND-1))
if [ -z "${CLUSTER}" ] || [ -z "${USERNAME}" ] || [ -z "${VM_NAME}" ]; then
    usage
fi
#
# End of variables

printf '%s\n'
# # check if password was enter in command arguments, if not prompt for password
if ! JQ_LOC="$(type -p jq)" || [ -z "$JQ_LOC" ]; then
  printf '%s\n' "The jq utility is not installed."
  printf '%s\n' "Install contructions can be found at https://stedolan.github.io/jq/download/"
  exit 1
fi
if [ -z $PASSWORD ]; then
  printf '%s' "Enter the $USERNAME password: "
  read -s PASSWORD
  echo
fi

AUTH_HASH=$(echo -n "$USERNAME:$PASSWORD" | openssl enc -base64)

# Get the VM data to pull the ID from
GET_VM=$(curl -s -H 'Content-Type: application/json' -H 'Authorization: Basic '"$AUTH_HASH"'' -X GET -k -l --write-out "HTTPSTATUS:%{http_code}" --connect-timeout 5 "https://$CLUSTER/api/v1/vmware/vm?name=$VM_NAME")

# extract the status
HTTP_STATUS=$(echo $GET_VM | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

# Provide an Error Message if there is no connectivity to the Cluster
if [ "$HTTP_STATUS" == "000" ]; then
  printf '%s\n' "ERROR: Unable to connect to $CLUSTER."
  exit 1
fi

# Provide an Error Message for any response other than 200 (success)
if [ "$HTTP_STATUS" -ne "200" ]; then
  ERROR_RESPONSE="${GET_VM//'HTTPSTATUS:'$HTTP_STATUS}"
  ERROR_MESSAGE=$( echo "$ERROR_RESPONSE" | jq -r '.message' )
  printf '%s\n' "ERROR: $ERROR_MESSAGE"
  exit 1
fi

HTTP_BODY=$(echo $GET_VM | sed -e 's/HTTPSTATUS\:.*//g')

# Number of results returned
TOTAL_VM_MATCHES=$( echo "$HTTP_BODY" | jq -r '.total' )


# Make sure there is only one match to the VM name so we can extract the correct VM ID
if [ "$TOTAL_VM_MATCHES" -ne "1" ]
then
  printf '%s\n' "ERROR: There are $TOTAL_VM_MATCHES results matching the VM '$VM_NAME'. Please verify the correct VM name."
  exit 1
fi 

# Unique ID of the supplied VM 
VM_ID=$( echo "$HTTP_BODY" | jq -r '.data[0].id' )

printf '%s\n' 'Rubrik On-Demand Snapshot'
printf '%s\n'

# Start the snapshot process
TAKE_SNAPSHOT=$(curl -s -k -X POST -H 'Authorization: Basic '"$AUTH_HASH"'' "https://$CLUSTER/api/v1/vmware/vm/$VM_ID/snapshot")

# URL to monitor the progress of the snapshot
URL=$( echo "$TAKE_SNAPSHOT" | jq -r '.links[0].href' )

# Print a waiting message while the snapshot is still in queue
while
    true
do 
    SNAPSHOT_STATUS=$(curl -s -H 'Content-Type: application/json' -H 'Authorization: Basic '"$AUTH_HASH"'' -X GET -k -l $URL)
    CURRENT_STATUS=$( echo "$SNAPSHOT_STATUS" | jq -r '.status' )

    if [ "$CURRENT_STATUS" == "QUEUED" ]; then
        printf '%s\n' 'Waiting for the Snapshot to begin...'
        sleep 35
    fi

    # Continue when the snapshot moves out of the queue
    if [ "$CURRENT_STATUS" == "RUNNING" ]; then
        break
    elif [ "$CURRENT_STATUS" == "SUCCEEDED" ]; then
        printf '%s\n'
        printf '%s\n' 'Snapshot successfully completed.'
        exit 1
    else
        continue
    fi   
done

printf '%s\n' 'Snapshot Progress: '
printf '%s\n'

# Loop through and print the current progress percent until the snapshot succeeds
while
    true
do 
    SNAPSHOT_STATUS=$(curl -s -H 'Content-Type: application/json' -H 'Authorization: Basic '"$AUTH_HASH"'' -X GET -k -l $URL)
    CURRENT_STATUS=$( echo "$SNAPSHOT_STATUS" | jq -r '.status' )    
    
    if [ "$CURRENT_STATUS" == "RUNNING" ]
    then
        CURRENT_PROGRESS=$( echo "$SNAPSHOT_STATUS" | jq -r '.progress' )
        printf '%s\n' $CURRENT_PROGRESS'%'
        sleep 20
    else
        printf '%s\n'
        printf '%s\n' 'Snapshot successfully completed.'
        break
    fi

    if [ "$CURRENT_STATUS" == "FAILED" ]
    then
        printf '%s\n'
        printf '%s\n' 'ERROR: The On-Demand Snapshot failed.'
        break
    fi

done

