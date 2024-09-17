# configured Vault's AWS Secret Engine through Terraform,
# used dynamic short-lived AWS credentials to provision infrastructure, and
# restricted the AWS credential's permissions by adjusting the corresponding Vault role

data "vault_generic_secret" "aws_credentials" {
  path = "aws-secrets/admin"
}

provider "aws" {
  access_key = data.vault_generic_secret.aws_credentials.data["aws_access_key_id"]
  secret_key = data.vault_generic_secret.aws_credentials.data["aws_secret_access_key"]
  region = var.region
}

provider "vault" {}

resource "aws_iam_user" "secrets_engine" {
  name = "${var.project_name}-user"
}

resource "aws_iam_access_key" "secrets_engine_credentials" {
  user = aws_iam_user.secrets_engine.name
}

resource "aws_iam_user_policy" "secrets_engine" {
  user = aws_iam_user.secrets_engine.name

  policy = jsonencode({
    Statement = [
      {
        Action = [
          "iam:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
    Version = "2012-10-17"
  })
}

### This is vault stuff

# the vault_aws_secret_backend.aws resource configures AWS Secrets Engine to generate a dynamic token that lasts for 2 minutes.
resource "vault_aws_secret_backend" "aws" {
  region = var.region
  path   = "${var.project_name}-path"

  access_key = aws_iam_access_key.secrets_engine_credentials.id
  secret_key = aws_iam_access_key.secrets_engine_credentials.secret

  default_lease_ttl_seconds = "22120"
}

# the vault_aws_secret_backend_role.admin resource configures a role for the AWS Secrets Engine named 
# dynamic-aws-creds-vault-admin-role with an IAM policy that allows it iam:* and ec2:* permissions.
# this is in vault 
resource "vault_aws_secret_backend_role" "admin" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "${var.project_name}-role"
  credential_type = "iam_user"

  policy_document = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:*",
        "ec2:*",
        "s3:*",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
