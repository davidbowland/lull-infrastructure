# Lull Infrastructure

Infrastructure as Code for the Lull project: the Lambda artifacts bucket, the CloudFormation and pipeline deployment roles, and the IAM users that `lull-api` and `lull-ui` authenticate as.

**Test deploys by CI, production by hand.** `.github/workflows/pipeline.yaml` deploys the test stack on every push, then prints the production changeset without executing it.

## Setup

The `developer` role and [AWS SAM CLI](https://aws.amazon.com/serverless/sam/) are required to deploy this project.

Install dependencies and validate the template:

```bash
npm install
sam validate --template template.yaml --region us-east-1 --lint
```

### CloudFormation

Execute the `deploy` script to deploy the infrastructure to test:

```bash
npm run deploy
```

There is no script for production. It is the one operation that has to be typed out, deliberately:

```bash
sam deploy --stack-name lull-infrastructure --template-file template.yaml --region us-east-1 --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --parameter-overrides Environment=prod
```

**Never deploy production without reading the changeset first.** Add `--no-execute-changeset` to print what will happen without doing it. This stack creates named IAM users and roles; a rename is a delete plus a create, and the delete takes the credentials the other pipelines are using with it.

### Pipeline

`.github/workflows/pipeline.yaml` runs on every push:

| Branch   | What happens                                                                                       |
| -------- | -------------------------------------------------------------------------------------------------- |
| feature  | Deploys `lull-infrastructure-test`                                                                 |
| `master` | Deploys `lull-infrastructure-test`, then creates — but does not execute — the production changeset |

The pipeline authenticates as `root-lull-infra` and assumes `full-access`. Both are created by
`root-infrastructure`, not by this stack, which is what makes a pipeline safe here: this template can
delete the `lull-*` users, but never the user the pipeline is authenticating as.

Production is the exception. The changeset is printed to the job log and applied by hand:

```bash
aws cloudformation execute-change-set --region us-east-1 --stack-name lull-infrastructure --change-set-name <name from the job log>
```

Required GitHub secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_ACCOUNT_ID`.
`GIT_EMAIL` is optional; without it the version-bump commit is authored as `github-actions[bot]`.

### AWS Credentials

To run locally, [AWS CLI](https://aws.amazon.com/cli/) is required in order to assume a role with permission to update resources. Install AWS CLI with:

```bash
brew install awscli
```

If file `~/.aws/credentials` does not exist, create it and add a default profile:

```toml
[default]
aws_access_key_id=<YOUR_ACCESS_KEY_ID>
aws_secret_access_key=<YOUR_SECRET_ACCESS_KEY>
region=us-east-1
```

If necessary, generate a [new access key ID and secret access key](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys).

Add a `developer` profile to the same credentials file:

```toml
[developer]
role_arn=arn:aws:iam::<AWS_ACCOUNT_ID>:role/developer
source_profile=default
mfa_serial=<YOUR_MFA_ARN>
region=us-east-1
```

If necessary, retrieve the ARN of the primary MFA device attached to the default profile:

```bash
aws iam list-mfa-devices --query 'MFADevices[].SerialNumber' --output text
```

`scripts/assumeDeveloperRole.sh`, which `deploy.sh` invokes, reads `AWS_ACCOUNT_ID` from the environment. Export it before deploying.

## Region

Everything lives in `us-east-1`. This is not a preference: a Lambda deployment package must live in a bucket in the function's own region, so this bucket's region _is_ `lull-api`'s region. CloudFront also requires its certificates there.

## Cross-repo coupling

`PipelineRole` grants S3 access to `lull-ui` and `lull-ui-test` by literal ARN. Those names must match the bucket `lull-ui`'s own template creates. IAM accepts a nonexistent ARN silently, so a mismatch surfaces only as an `AccessDenied` when `lull-ui` deploys.

## Additional Documentation

- [AWS CLI](https://aws.amazon.com/cli/)

- [AWS SAM CLI](https://aws.amazon.com/serverless/sam/)

- [AWS CloudFormation](https://aws.amazon.com/cloudformation/)

- [AWS credentials](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html)

## Pipeline credentials

The stack creates the pipeline **users** but not their access keys — CloudFormation can create an
`AWS::IAM::AccessKey`, but that writes the secret into stack outputs, so it is done by hand instead.

After deploying, for each of `lull-api-user` and `lull-ui-user`:

    aws iam create-access-key --user-name lull-api-user

Load the pair into the corresponding repo's GitHub secrets as `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY`. Each pipeline also needs `AWS_ACCOUNT_ID`, `AWS_REGION`, and `GIT_EMAIL`.

Until this is done, `lull-api` and `lull-ui` cannot deploy even though this stack exists.

## Privilege separation

Deliberately tighter than `connections-infrastructure`, which this template was derived from:

- The **test** pipeline role has no access to the **production** UI bucket. In the source both
  buckets are listed unconditionally, and `copyToS3.sh` ends in `aws s3 sync . --delete`.
- Both pipeline users can assume both roles, unchanged from the source and **deliberate**: a single
  `AWS_ACCESS_KEY_ID` secret drives the whole pipeline, one run assumes testing and then production,
  and the staging user is the one used in every environment. There is no credential-level separation
  between test and prod here, by choice — the separation lives on the roles instead.
- `cloudformation:*` is scoped to `lull-*` stacks rather than granted on `Resource: '*'`.
- **`CloudFormationRole` cannot mint privilege for itself.** The whole `iam:*` namespace is
  excluded and granted back narrowly: role creation only under a permissions boundary,
  `AttachRolePolicy` only for `AWSLambdaBasicExecutionRole`, everything scoped to `role/lull-*`.

  Two things this closes that a name-scope alone does not. Scoping `CreateRole` to `role/lull-*`
  constrains the role's _name_, not its trust policy or what may be attached to it — so
  `RoleName: lull-anything` with `AdministratorAccess` was reachable. And `iam:*User` matches only
  actions whose name _ends_ in `User`, so `iam:PutUserPolicy`, `iam:AttachUserPolicy` and
  `iam:CreateAccessKey` were never excluded — an `AWS::IAM::Policy` naming the pipeline user made
  that user an account administrator.

  If a future stack needs a managed policy these grants do not cover, widen the
  `ArnEquals` condition deliberately rather than removing it.
