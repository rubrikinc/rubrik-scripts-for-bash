#!/bin/bash

########################################################################################################
# Title:    Bash-ServiceAccount.sh
# Summary:  Authenticate BASH using Rubrik service account user.
# Author:   Parag Bhardwaj
#
# REQUIREMENTS:
# jq is required to parse curl response. You can usually get the jq utility in the add on
# repository of most linux distros.
#
# USAGE: ./Bash-ServiceAccount.sh -c 192.X.X.X -serviceAccountId myServiceAccountID -secret SecretKeyOfTheServiceAccountUser
########################################################################################################

#Modify the following parameters
c="X.X.X.X"
serviceAccountId="User:::5741XXXXXXad6"
secret="0reaJXXXXXXXX+yWApJF"

# check jq is installed
if ! JQ_LOC="$(type -p jq)" || [ -z "$JQ_LOC" ]; then
  printf '%s\n' "The jq utility is not installed."
  printf '%s\n' "Install contructions can be found at https://stedolan.github.io/jq/download/"
  exit 1
fi

#Create a session passing the Service account ID and Secret
session=$(curl -X POST "https://$c/api/v1/service_account/session" -H "accept: application/json"  -H "Content-Type: application/json" -d "{ \"serviceAccountId\": \"$serviceAccountId\", \"secret\": \"$secret\"}" --insecure)

#Get the token ID (will be used to pass the token in the authentication parameters)
AUTH_TOKEN=$(echo "$session" | jq -r .token)

#Get the session ID (will be used to terminate the session in the end)
sessionId=$(echo "$session" | jq -r .sessionId)

#OPTIONAL IF YOU WANT TO PRINT THE TOKEN AND SESSION ID
#printf '%s\n' "Token is: $AUTH_TOKEN"
#printf '%s\n' "Session ID is: $sessionId"

#Testing to fetch the cluster details using the API key of the service account.

test=$(curl -X GET "https://$c/api/v1/cluster/me" -H "accept: application/json" -H "Authorization: Bearer $AUTH_TOKEN" --insecure)
printf '%s\n' "$test"

#Make sure to end the session because only 10 active sessions are allowed per service account.
end_session=$(curl -X DELETE "https://$c/api/v1/session/$sessionId" -H "accept: application/json" -H "Authorization: Bearer $AUTH_TOKEN" --insecure)
printf '%s\n' "session ended successfully"
