# Project Guidelines

**Always commit changes** after completing work unless explicitly told not to.

## What this repo is

Account-level AWS resources for Lull: the Lambda artifacts bucket, the CloudFormation and pipeline
deployment roles, and the pipeline users `lull-api` and `lull-ui` authenticate as. No application
code, no Lambdas, no tests.

**Test deploys by CI, production by hand.** `.github/workflows/pipeline.yaml` deploys the test stack
on every push and prints the production changeset without executing it. The credentials it uses
belong to `root-lull-infra`, a user `root-infrastructure` creates — not this stack. That is the only
reason a pipeline is safe here: this template can delete the `lull-*` users, but never the user the
pipeline itself authenticates as.

## Rules

**Never deploy production without reading the changeset first.** `sam deploy --no-execute-changeset`
prints what will happen. This stack creates named IAM users and roles; a rename is a delete plus a
create, and the delete takes the credentials the other pipelines are using with it. The pipeline
enforces this by never executing the production changeset — do not "fix" that by dropping the flag.
The test stack deploys unattended, which is the one place this rule is traded away for automation.

**Prod and test differ only by the `Environment` parameter.** Every name comes from the
`EnvironmentMap` mapping. Never hardcode a name in a resource — if you find yourself typing `lull-`
outside the mapping block, it belongs in the mapping.

**The artifacts bucket stays private.** All four `PublicAccessBlockConfiguration` flags are on. It
holds deployment packages, not content, and nothing should ever be served from it.

**Never `git push`** unless explicitly asked.
