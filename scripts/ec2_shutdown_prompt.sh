#!/bin/bash

PARAM_NAME="/ec2/shutdown_at"
REGION="ap-south-1"

NEW_TIME=$(date -u -v+1H +"%Y-%m-%dT%H:%M:%SZ")

/usr/local/bin/aws ssm put-parameter \
  --name "$PARAM_NAME" \
  --value "$NEW_TIME" \
  --type String \
  --overwrite \
  --region "$REGION"
