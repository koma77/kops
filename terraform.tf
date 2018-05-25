#

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_vpc" "kops" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "kops" {
  vpc_id = "${aws_vpc.kops.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.kops.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.kops.id}"
}

resource "aws_subnet" "kops" {
  vpc_id                  = "${aws_vpc.kops.id}"
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_iam_role" "kops" {
  name        = "kops"
  description = "Managed by terraform (kops)"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "kops" {
  name = "kops"
  role = "${aws_iam_role.kops.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
          "ec2:*",
          "route53:*",
          "s3:*",
          "iam:*",
          "vpc:*",
          "elasticloadbalancing:*",
          "autoscaling:*"
        ],
        "Resource": [ "*" ]
    }
  ]
}
EOF
}

resource "aws_s3_bucket" "kops-state" {
  bucket = "kops-state-bucket-ap-southeast-1"
  acl    = "private"

  tags {
    Name = "kops state bucket"
  }
}

resource "aws_iam_instance_profile" "kops" {
  name = "kops"
  role = "${aws_iam_role.kops.name}"
}

resource "aws_security_group" "kops" {
  name        = "kops"
  description = "Managed by terraform (kops)"
  vpc_id      = "${aws_vpc.kops.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "tf"
  public_key = "${file("~/.ssh/tf.pub")}"
}

resource "aws_instance" "kops" {
  connection {
    user        = "centos"
    private_key = "${file("~/.ssh/tf")}"
  }

  instance_type        = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.kops.id}"

  ami = "ami-da6151a6"

  key_name = "${aws_key_pair.auth.id}"

  vpc_security_group_ids = ["${aws_security_group.kops.id}"]
  subnet_id              = "${aws_subnet.kops.id}"

  root_block_device {
    volume_size           = "8"
    delete_on_termination = "true"
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u centos --private-key ~/.ssh/tf -i ${aws_instance.kops.public_ip},  ansible/kops.yml"
  }
}

output "kops_ip" {
  value = "${aws_instance.kops.public_ip}"
}
