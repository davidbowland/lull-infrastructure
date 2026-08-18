# Lull Infrastructure

Infrastructure as Code for the Lull project: the Lambda artifacts bucket, the CloudFormation and pipeline deployment roles, and the IAM users that `lull-api` and `lull-ui` authenticate as.

**Deployed by hand, never by CI.** The other two repos deploy themselves using the roles this stack creates, which is exactly why this one cannot.

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

**Never deploy without reading the changeset first.** Add `--no-execute-changeset` to print what will happen without doing it. This stack creates named IAM users and roles; a rename is a delete plus a create, and the delete takes the credentials the other pipelines are using with it.

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

`deploy.sh` reads `AWS_ACCOUNT_ID` from the environment when assuming the `developer` role.

## Region

Everything lives in `us-east-1`. This is not a preference: a Lambda deployment package must live in a bucket in the function's own region, so this bucket's region _is_ `lull-api`'s region. CloudFront also requires its certificates there.

## Cross-repo coupling

`PipelineRole` grants S3 access to `lull-ui` and `lull-ui-test` by literal ARN. Those names must match the bucket `lull-ui`'s own template creates. IAM accepts a nonexistent ARN silently, so a mismatch surfaces only as an `AccessDenied` when `lull-ui` deploys.

## Additional Documentation

- [AWS CLI](https://aws.amazon.com/cli/)

- [AWS SAM CLI](https://aws.amazon.com/serverless/sam/)

- [AWS CloudFormation](https://aws.amazon.com/cloudformation/)

- [AWS credentials](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html)
