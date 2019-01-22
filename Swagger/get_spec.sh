#!/bin/bash
# Outputs the Swagger specs for a Rubrik cluster, which can then be imported into Postman
RUBRIK_IP='rubrik.demo.com'
curl -Lks https://$RUBRIK_IP/docs/v1/api-docs -o ./v1-spec.yml
sed -i '' 's/basePath: \/api\/v1/basePath: "{{rubrik_ip}}\/api\/v1"/g' v1-spec.yml
curl -Lks https://$RUBRIK_IP/docs/internal/api-docs -o ./internal-spec.yml
sed -i '' 's/basePath: \/api\/internal/basePath: "{{rubrik_ip}}\/api\/internal"/g' internal-spec.yml
