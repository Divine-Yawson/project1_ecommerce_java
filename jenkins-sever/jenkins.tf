# -----------------------------
# Provider
# -----------------------------
provider "aws" {
  region = "us-east-1" # Change if using a different region
}

# -----------------------------
# Data Sources
# -----------------------------
# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the default subnets of the default VPC
data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -----------------------------
# Jenkins Security Group
# -----------------------------
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg2"
  description = "Allow SSH and Jenkins access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------
# Jenkins EC2 Instance
# -----------------------------
resource "aws_instance" "jenkins_instance" {
  ami                    = "ami-02457590d33d576c3"
  instance_type          = "t3.medium"
  key_name               = "tonykey"
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  subnet_id              = data.aws_subnets.default_subnets.ids[0]

  user_data = <<-EOF
#!/bin/bash
exec > >(tee /var/log/userdata.log | logger -t userdata) 2>&1
set -x

# Wait for yum lock to be released
while sudo fuser /var/run/yum.pid >/dev/null 2>&1; do
  echo "Waiting for yum lock..."
  sleep 5
done

yum update -y
yum install -y git wget unzip docker maven

# Install Java 17
yum install -y java-17-amazon-corretto-devel

# Start and enable Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Wait for yum lock again
while sudo fuser /var/run/yum.pid >/dev/null 2>&1; do
echo "Waiting for yum lock again..."
sleep 5
done

yum install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install kubectl (EKS v1.29)
curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.0/2024-05-10/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
EOF

  tags = {
    Name = "Jenkins-Server"
  }
}

# -----------------------------
# Outputs
# -----------------------------
output "jenkins_url" {
  value = "http://${aws_instance.jenkins_instance.public_ip}:8080"
}
