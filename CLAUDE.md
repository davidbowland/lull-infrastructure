# Project Guidelines

**Always commit changes** after completing work unless explicitly told not to.

## What this repo is

Account-level AWS resources for Lull: the Lambda artifacts bucket, the CloudFormation and pipeline
deployment roles, and the pipeline users `lull-api` and `lull-ui` authenticate as. No application
code, no Lambdas, no tests.

**Deployed by hand, never by CI.** The other two repos deploy themselves using the roles this stack
creates, which is exactly why this one cannot.

## Rules

**Never deploy without reading the changeset first.** `sam deploy --no-execute-changeset` prints
what will happen. This stack creates named IAM users and roles; a rename is a delete plus a create,
and the delete takes the credentials the other pipelines are using with it.

**Prod and test differ only by the `Environment` parameter.** Every name comes from the
`EnvironmentMap` mapping. Never hardcode a name in a resource — if you find yourself typing `lull-`
outside the mapping block, it belongs in the mapping.

**The artifacts bucket stays private.** All four `PublicAccessBlockConfiguration` flags are on. It
holds deployment packages, not content, and nothing should ever be served from it.

**Never `git push`** unless explicitly asked.
