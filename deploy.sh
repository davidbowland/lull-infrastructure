#!/usr/bin/env bash

# Stop immediately on error
set -e

if [[ -z "$1" ]]; then
  $(./scripts/assumeDeveloperRole.sh)
fi

# Deploy infrastructure

# --confirm-changeset prints the changeset and waits for a yes before executing.
# This repo's first rule is "never deploy without reading the changeset", and this
# is the only scripted deploy path -- without the flag the rule is enforced only by
# the operator remembering to read a script they are not running interactively.
# It creates named IAM users and roles, where a rename is a delete plus a create.
sam deploy --stack-name lull-infrastructure-test \
  --template-file template.yaml --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM \
  --confirm-changeset \
  --no-fail-on-empty-changeset \
  --parameter-overrides Environment=test
