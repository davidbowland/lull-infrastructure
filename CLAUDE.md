# Project Guidelines

**Always commit changes** after completing work unless explicitly told not to.

## What this repo is

Account-level AWS resources for Lull: the Lambda artifacts bucket, the CloudFormation and pipeline
deployment roles, and the pipeline users `lull-api` and `lull-ui` authenticate as. No application
code, no Lambdas, no tests.

**Deployed by `.github/workflows/pipeline.yaml`, same shape as every sibling infra repo:** feature
branches to test, `master` to test and then production. The credentials it uses belong to
`root-lull-infra`, a user `root-infrastructure` creates — not this stack. That is the only reason a
pipeline is safe here: this template can delete the `lull-*` users, but never the user the pipeline
itself authenticates as.

## Rules

**Never merge to `master` without reading the production changeset first.** `sam deploy
--no-execute-changeset` prints what will happen. The pipeline does not gate this — `master` reaches
production unattended, like every sibling repo — so the reading happens before the merge, not after.
This stack creates named IAM roles; a rename is a delete plus a create, and the delete takes the
credentials the other pipelines are using with it. The pipeline users are CloudFormation-named on
purpose, so editing them does not force a replacement — but any change that _does_ replace a user
still destroys its access keys.

**Prod and test differ only by the `Environment` parameter.** Every name comes from the
`EnvironmentMap` mapping. Never hardcode a name in a resource — if you find yourself typing `lull-`
outside the mapping block, it belongs in the mapping.

**The artifacts bucket stays private.** All four `PublicAccessBlockConfiguration` flags are on. It
holds deployment packages, not content, and nothing should ever be served from it.

**Never `git push`** unless explicitly asked.
