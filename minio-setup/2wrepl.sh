#!/bin/sh

mc config host add minio http://minio:9000 tOMthxlS4I2K5aK53lDN dZ0szvjj4gWboi73X6uJyWHlkLkGX6hZXgmcyyLZ
mc config host add minio2 http://minio2:9000 ELyJtCrwG8zoklm8VZev xkkn1hOnu2QkdaXTV34WmQlEn2w0p9zmnnN3ABzJ
# Create buckets with versioning and object locking enabled.
mc mb -l minio/replication
mc mb -l minio2/replication

#### Create a replication admin on source alias
# create a replication admin user : repladmin
#mc admin user add source minio minio123

# create a replication policy for repladmin
cat >repladmin-policy-source.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": [
            "admin:SetBucketTarget",
            "admin:GetBucketTarget"
        ],
        "Effect": "Allow",
        "Sid": ""
     }, 
     {
      "Effect": "Allow",
      "Action": [
       "s3:GetReplicationConfiguration",
       "s3:PutReplicationConfiguration",
       "s3:ListBucket",
       "s3:ListBucketMultipartUploads",
       "s3:GetBucketLocation",
       "s3:GetBucketVersioning"
      ],
      "Resource": [
       "arn:aws:s3:::bucket"
      ]
     }
    ]
   }
EOF
mc admin policy create minio repladmin-policy ../repladmin-policy-source.json
mc admin policy create minio2 repladmin-policy ../repladmin-policy-source.json

#cat ./repladmin-policy-source.json

#assign this replication policy to repladmin
#mc admin policy attach minio/replication repladmin-policy --user=admin
#mc admin policy attach minio2/replication repladmin-policy --user=admin
### on dest alias
# Create a replication user : repluser on dest alias
#mc admin user add dest minio minio123

# create a replication policy for repluser
# Remove "s3:GetBucketObjectLockConfiguration" if object locking is not enabled, i.e. bucket was not created with `mc mb --with-lock` option
# Remove "s3:ReplicateDelete" if delete marker replication is not required
cat >replpolicy.json <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Effect": "Allow",
   "Action": [
    "s3:GetReplicationConfiguration",
    "s3:ListBucket",
    "s3:ListBucketMultipartUploads",
    "s3:GetBucketLocation",
    "s3:GetBucketVersioning",
    "s3:GetBucketObjectLockConfiguration"
   ],
   "Resource": [
    "arn:aws:s3:::bucket"
   ]
  },
  {
   "Effect": "Allow",
   "Action": [
    "s3:GetReplicationConfiguration",
    "s3:ReplicateTags",
    "s3:AbortMultipartUpload",
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:GetObjectVersionTagging",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ReplicateObject",
    "s3:ReplicateDelete"
   ],
   "Resource": [
    "arn:aws:s3:::bucket/*"
   ]
  }
 ]
}
EOF
mc admin policy create minio2 replpolicy ../replpolicy.json
mc admin policy create minio replpolicy ../replpolicy.json
#cat ./replpolicy.json

# assign this replication policy to repluser
mc admin policy attach minio2 replpolicy repladmin-policy --user=admin 
mc admin policy attach minio replpolicy repladmin-policy --user=admin 

mc admin policy attach minio2 replpolicy repladmin-policy --group=administrator
mc admin policy attach minio replpolicy repladmin-policy --group=administrator
# UPload file with multi part upload
#mc put ~/elasticsearch-8.15.2-windows-x86_64.zip minio/bucket --parallel 8 --part-size 60MiB

# configure replication config to remote bucket at http://localhost:9000
mc replicate add minio/replication --remote-bucket http://minio:minio123@minio2:9000/replication \
	--replicate existing-objects,delete,delete-marker,replica-metadata-sync


