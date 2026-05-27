# WordPress on AWS with Terraform

This project deploys WordPress on AWS with an Application Load Balancer, Auto Scaling Group, private RDS MySQL database, and an S3 bucket mounted as a filesystem on every EC2 instance with `s3fs-fuse`.

## What It Creates

- VPC with public and private subnets
- NAT gateway for private EC2 instances to install packages
- Public ALB with HTTP to HTTPS redirect
- HTTPS listener using ACM certificate
- Route 53 alias record for `wordpress.neatfleets-services.com`
- Auto Scaling Group running WordPress on Ubuntu
- Private RDS MySQL database
- S3 bucket mounted at `/var/www/html/wp-content/uploads` on every EC2 instance
- Custom WordPress homepage so the Ubuntu default page does not appear

## Before Running

Update `terraform.tfvars` before apply:

- `key_name`: your existing EC2 key pair
- `s3_bucket_name`: must be globally unique across AWS
- `db_password`: change to a strong database password
- `wp_admin_password`: change to a strong WordPress admin password
- `wp_admin_email`: set to your real admin email
- `ssh_ingress_cidr`: use a trusted VPN, bastion, or admin CIDR

The backend in `providers.tf` expects this S3 bucket and lockfile to already exist:

- S3 bucket: `baho-backup-bucket`


## Deploy

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

When the apply completes, open:

```text
https://wordpress.neatfleets-services.com
```


## Verify S3FS Mount

The WordPress EC2 instances are private, so the easiest way to check them is with AWS Systems Manager Session Manager. The Terraform EC2 role includes `AmazonSSMManagedInstanceCore`.

### 1. Find A WordPress Instance

In the AWS Console:

1. Go to **EC2**.
2. Open **Instances**.
3. Search for instances named `neatfleets-wp-wordpress`.
4. Select one running instance.
5. Click **Connect**.
6. Choose **Session Manager**.
7. Click **Connect**.

You can also use the AWS CLI:

```bash
aws ec2 describe-instances \
  --region us-west-2 \
  --filters "Name=tag:Name,Values=neatfleets-wp-wordpress" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text
```

Then connect:

```bash
aws ssm start-session --region us-west-2 --target INSTANCE_ID
```

### 2. Check That S3 Is Mounted

Inside the EC2 instance session, run:

```bash
mount | grep s3fs
```

Expected result: you should see the S3 bucket mounted on:

```text
/var/www/html/wp-content/uploads
```

You can also run:

```bash
df -h | grep uploads
mountpoint /var/www/html/wp-content/uploads
```

Expected result:

```text
/var/www/html/wp-content/uploads is a mountpoint
```

### 3. Create A Test File On The Mounted Folder

Inside the EC2 instance:

```bash
sudo bash -c 'echo "S3FS mount test from $(hostname) at $(date)" > /var/www/html/wp-content/uploads/s3fs-test.txt'
sudo chown www-data:www-data /var/www/html/wp-content/uploads/s3fs-test.txt
ls -l /var/www/html/wp-content/uploads/s3fs-test.txt
cat /var/www/html/wp-content/uploads/s3fs-test.txt
```

### 4. Verify The File In S3

From your local terminal or CloudShell:

```bash
aws s3 ls s3://neatfleets-wordpress-media-546310954125/s3fs-test.txt --region us-west-2
aws s3 cp s3://neatfleets-wordpress-media-546310954125/s3fs-test.txt - --region us-west-2
```

If the file appears in S3, the mount is working.

### 5. Confirm The File Is Shared Across EC2 Instances

Connect to a second WordPress EC2 instance with Session Manager and run:

```bash
ls -l /var/www/html/wp-content/uploads/s3fs-test.txt
cat /var/www/html/wp-content/uploads/s3fs-test.txt
```

If the second instance sees the same file, then all EC2 instances are using the same S3-backed uploads filesystem.

### 6. Browser Test

Open this URL in the browser:

```text
https://wordpress.neatfleets-services.com/wp-content/uploads/s3fs-test.txt
```

If the text file loads, Apache and WordPress are serving files from the S3FS-mounted uploads directory.

### 7. Cleanup Test File

Remove the test file from any EC2 instance:

```bash
sudo rm -f /var/www/html/wp-content/uploads/s3fs-test.txt
```

Or remove it directly from S3:

```bash
aws s3 rm s3://neatfleets-wordpress-media-546310954125/s3fs-test.txt --region us-west-2
```


## Troubleshoot Missing S3FS Mount

If `/var/www/html/wp-content/uploads` does not exist, user data did not finish. Check the cloud-init status from Session Manager:

```bash
cloud-init status --long
sudo tail -n 160 /var/log/cloud-init-output.log
```

A common failure is an `s3fs-fuse` compile error such as `fuse3 >= 3.0.0 was not met`. This project now installs the Ubuntu `s3fs` package directly with FUSE3 support instead of compiling from source.

The ALB health check uses `/health.html`, which is created only after WordPress and the S3FS mount finish successfully. If the setup fails, the target should stay unhealthy and the Auto Scaling Group can replace it after the grace period.

After changing user data or the launch template, run:

```bash
terraform apply "tfplan"
```

The Auto Scaling Group includes an instance refresh, so launch template changes roll out to new instances.

## Important Notes

- The Route 53 record uses `allow_overwrite = true`, so Terraform can point an existing `wordpress.neatfleets-services.com` record to the new ALB.
- Your ACM certificate must be in `us-west-2`, the same region as the ALB. The ARN provided is used, not just the certificate ID.
- WordPress uploads are stored in S3 through the mount at `/var/www/html/wp-content/uploads`.
- EC2 instances are private; use SSM Session Manager or a bastion/VPN for access.
