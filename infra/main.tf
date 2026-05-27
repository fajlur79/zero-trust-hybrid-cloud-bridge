# trivy:ignore:AVD-AWS-0178 - VPC Flow Logs disabled to prevent unnecessary CloudWatch costs for personal project
resource "aws_vpc" "wg_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "WireGuard-VPC" }
}

resource "aws_internet_gateway" "wg_igw" {
  vpc_id = aws_vpc.wg_vpc.id
}

resource "aws_subnet" "wg_subnet" {
  vpc_id     = aws_vpc.wg_vpc.id
  cidr_block = "10.0.1.0/24"

  # trivy:ignore:AVD-AWS-0164 - Public IP intentionally required for WireGuard endpoint
  map_public_ip_on_launch = true
}

resource "aws_route_table" "wg_public_rt" {
  vpc_id = aws_vpc.wg_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wg_igw.id
  }
}

resource "aws_route_table_association" "wg_rt_assoc" {
  subnet_id      = aws_subnet.wg_subnet.id
  route_table_id = aws_route_table.wg_public_rt.id

}

#Security Group 

resource "aws_security_group" "wg_sg" {
  name        = "wireguard-sg"
  description = "Allow Wireguard traffic and SSH traffic"
  vpc_id      = aws_vpc.wg_vpc.id

  ingress {
    description = "Allow inbound Wireguard UDP traffic"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # trivy:ignore:AVD-AWS-0104 - WireGuard router requires unrestricted outbound internet access
  egress {
    description = "Allow all outbound traffic for internet routing"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_eip" "wg_eip" {
  domain = "vpc"
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "wg_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.wg_subnet.id

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  source_dest_check = false

  vpc_security_group_ids = [aws_security_group.wg_sg.id]

  iam_instance_profile = aws_iam_instance_profile.wg_profile.name

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y wireguard
              
              apt install -y awscli

              echo "export TERM=xterm-256color" | tee -a /home/ubuntu/.bashrc
              chown -R ubuntu:ubuntu /home/ubuntu/.bashrc

              EC2_PRIV_KEY=$(aws ssm get-parameter \
                  --name "ec2_private_key" \
                  --with-decryption \
                  --query "Parameter.Value" \
                  --output text \
                  --region ap-south-1)

              cat <<WG_CONF > /etc/wireguard/wg0.conf
              [Interface]
              PrivateKey = $EC2_PRIV_KEY
              Address = 10.200.200.1/24
              ListenPort = 51820

              [Peer]
              PublicKey = ${var.local_public_key}
              AllowedIPs = 10.10.10.0/24, 10.200.200.0/24
              WG_CONF

              chmod 600 /etc/wireguard/wg0.conf

              systemctl enable --now wg-quick@wg0

              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf

              EC2_PRIV_KEY="cleared"
              EOF
  tags      = { Name = "WireGuard-Bridge-Router" }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.wg_instance.id
  allocation_id = aws_eip.wg_eip.id
}

output "wg_eip" {
  value = aws_eip.wg_eip.public_ip
}
