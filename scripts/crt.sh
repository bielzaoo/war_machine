#!/bin/bash

curl -s "https://crt.sh/?q=${1}&output=json" | jq -r '.[].name_value' | sed 's/\\n/\n/g' | grep -vF '*.' | sort -u
