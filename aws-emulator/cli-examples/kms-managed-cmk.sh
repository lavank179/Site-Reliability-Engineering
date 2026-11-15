#!/bin/bash

# Upload a file encrypted with the AWS Managed S3 Key (aws:kms):
echo "Encrypted with AWS Managed Key" > managed-secret.txt
aws s3 cp managed-secret.txt s3://testbucket/managed-secret.txt \
  --sse aws:kms

# Verify encryption metadata and read the file:
aws s3api head-object --bucket testbucket --key managed-secret.txt
aws s3 cp s3://testbucket/managed-secret.txt -


# --- create a new KMS CMK and use it to encrypt a file:
aws kms create-key \
  --description "Practice CMK for S3 testing" \
  --profile default

aws kms create-alias \
  --alias-name alias/my-practice-cmk \
  --target-key-id e158c4c3-3075-409a-adee-e438d2a29069 \
  --profile default




# First, test what happens when your assumed role (MyUserTaggedRole) tries to use the CMK without explicit KMS permissions.
# • Attempt to upload a file using the CMK (from your assumed-role terminal):bash, below will fail with not authorized to perform: kms:GenerateDataKey
echo "Top secret CMK data" > cmk-secret.txt
aws s3 cp cmk-secret.txt s3://testbucket/cmk-secret.txt \
  --sse aws:kms \
  --sse-kms-key-id alias/my-practice-cmk



# now give the kms permissions to the role MyUserTaggedRole, so that it can use the CMK to encrypt/decrypt files in S3
aws iam put-role-policy \
  --role-name MyUserTaggedRole \
  --policy-name MyRolePermissions \
  --profile default \
  --policy-document "$(cat << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::testbucket",
        "arn:aws:s3:::testbucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:GenerateDataKey",
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:us-east-1:000000000000:key/e158c4c3-3075-409a-adee-e438d2a29069"
    }
  ]
}
EOF
)"

# now try again to upload a file using the CMK (from your assumed-role terminal):bash, below will succeed
aws s3 cp cmk-secret.txt s3://testbucket/cmk-secret.txt \
  --sse aws:kms \
  --sse-kms-key-id alias/my-practice-cmk

aws s3 cp s3://testbucket/cmk-secret.txt -