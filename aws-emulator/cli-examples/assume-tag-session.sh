#!/bin/bash

#create s3 bucket using default profile, as user1 does not have permission to create bucket
aws s3api create-bucket --bucket testbucket --region us-east-1

aws iam create-role \
  --role-name MyUserTaggedRole \
  --assume-role-policy-document "$(cat << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::000000000000:user/user1"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
EOF
)"




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
    }
  ]
}
EOF
)"


# create user

aws iam create-user --user-name user1


# give identity-based policy to user1 to allow sts:AssumeRole and sts:TagSession even trust policy there, identity-based policy is required to allow user1 to assume role with tags

aws iam put-user-policy \
  --user-name user1 \
  --policy-name AllowAssumeTaggedRole \
  --policy-document "$(cat << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ],
      "Resource": "arn:aws:iam::000000000000:role/MyUserTaggedRole"
    }
  ]
}
EOF
)"

# To log in via the CLI, generate an Access Key ID and Secret Access Key for the new user.
aws iam create-access-key --user-name user1

# {
#     "AccessKey": {
#         "UserName": "user1",
#         "AccessKeyId": "EMULATORAKY4SHWEAJLJ",
#         "Status": "Active",
#         "SecretAccessKey": "GENERATE_NEW",
#         "CreateDate": "2026-11-15T12:55:49.545000+00:00"
#     }
# }



# login to user1 via CLI using the generated Access Key ID and Secret Access Key
aws configure --profile user1 

export AWS_PROFILE=user1




#now s3 ls bucket name wont work for user1, coz that role works only after assuming the role, so we will assume the role and then list the bucket


aws sts assume-role \
  --role-arn arn:aws:iam::000000000000:role/MyUserTaggedRole \
  --role-session-name TaggedSessionTest \
  --tags Key=Project,Value=Alpha Key=Environment,Value=Dev
