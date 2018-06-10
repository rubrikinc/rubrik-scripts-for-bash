#!/bin/bash
RUBRIK_HOST="rubrik.demo.com"
# if /etc/debian_version exists then this is Debian type OS
if [ -f "/etc/debian_version" ]; then
   URL="https://$RUBRIK_HOST/connector/rubrik-agent.x86_64.deb"
   curl -k $URL -o /tmp/rubrik-agent.x86_64.deb
   dpkg -i /tmp/rubrik-agent.x86_64.deb
fi
# if /etc/redhat-release exists then this is RedHat type OS
if [ -f "/etc/redhat-release" ]; then
   URL="https://$RUBRIK_HOST/connector/rubrik-agent.x86_64.rpm"
   curl -k $URL -o /tmp/rubrik-agent.x86_64.rpm
   rpm -i /tmp/rubrik-agent.x86_64.rpm
fi
