#!/bin/bash

PARAM_NAME="/ec2/shutdown_at"
REGION="ap-south-1"

CHOICE=$(osascript <<EOF
display dialog "EC2 will shut down at 11:00 PM.\n\nPostpone by 1 hour?" \
buttons {"No", "Yes"} default button "Yes" giving up after 900
EOF
)

if [[ "$CHOICE" != *"Yes"* ]]; then
  echo "No postpone"
  exit 0
fi

# Compute new shutdown time = now + 1 hour (UTC)
NEW_TIME=$(date -u -v+1H +"%Y-%m-%dT%H:%M:%SZ")

aws ssm put-parameter \
  --name "$PARAM_NAME" \
  --value "$NEW_TIME" \
  --type String \
  --overwrite \
  --region "$REGION"

echo "Shutdown postponed until $NEW_TIME"

