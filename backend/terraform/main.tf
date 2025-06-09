provider "aws" {
  region = "us-east-1"
}

# Use default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  # Optional: filter out unsupported AZs for EKS control plane
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"] # Remove unsupported us-east-1e
  }
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = "ecommerce-cluster"
  cluster_version = "1.29"
  vpc_id          = data.aws_vpc.default.id
  subnet_ids      = data.aws_subnets.default_subnets.ids
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      desired_size    = 2
      max_size        = 3
      min_size        = 1
      instance_types  = ["t3.medium"]
      iam_role_arn    = aws_iam_role.eks_node_role.arn
    }
  }
}

# Jenkins Security Group
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins access"

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

# Jenkins EC2 Instance
resource "aws_instance" "jenkins_instance" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t3.medium"
  key_name               = "tonykey"
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  subnet_id              = data.aws_subnets.default_subnets.ids[0]

  user_data = <<-EOF
             #!/bin/bash
#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -xe

# Update packages
yum update -y

# Install Docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Java 11
amazon-linux-extras enable java-openjdk11
yum clean metadata
yum install -y java-11-openjdk

# Install Maven
yum install -y maven

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
yum install -y unzip
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl
curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.0/2024-05-10/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Pull Jenkins image
docker pull jenkins/jenkins:lts

# Run Jenkins container
docker run -d --name jenkins -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts

  EOF

  tags = {
    Name = "Jenkins-Server"
  }
}

# Outputs
output "jenkins_url" {
  value = "http://${aws_instance.jenkins_instance.public_ip}:8080"
}

output "ssh_command" {
  value = "ssh -i tonykey.pem ec2-user@${aws_instance.jenkins_instance.public_ip}"
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region us-east-1 --name ${module.eks.cluster_name}"
}
