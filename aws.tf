provider "aws" {
  region = "ap-south-1"
  profile = "kavin"
}

resource "aws_security_group" "kavinsecgrp" {
  name        = "kavinsecgrp"
  description = "Allow HTTP inbound traffic"
  vpc_id      = "vpc-f5e1fe9d"

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security"
  }
}


resource "aws_instance" "myweb" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "kavin-key"
  security_groups = ["kavinsecgrp"]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/mukul jeveriya/Downloads/kavin-key.pem")
    host     = aws_instance.myweb.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install httpd -y",
      "sudo yum install git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "kavin-OS"
  }
}

resource "null_resource" "image"{
  provisioner "local-exec" {
    command = "git clone https://github.com/kavinjaveriya/cloud.git images"
  }
}

resource "aws_ebs_volume" "kavinvol" {
  availability_zone = aws_instance.myweb.availability_zone
  size = 1
  tags = {
    Name = "kavinvol1"
  }
}

resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.kavinvol.id
  instance_id = aws_instance.myweb.id
  force_detach = true
}

output "myos_ip" {
  value = aws_instance.myweb.public_ip
}


resource "null_resource" "nulllocal2"  {
  provisioner "local-exec" {
      command = "echo  ${aws_instance.myweb.public_ip} > publicip.txt"
    }
}


resource "aws_s3_bucket" "kavinbucket" {
  bucket = "kavinbucket1"
  acl    = "public-read"
  region = "ap-south-1"
  tags = {
    Name = "kavin_bucket1"
  }
}
locals {
  s3_origin_id = "s3_origin"
}

resource "aws_s3_bucket_object" "object"{
  depends_on = [aws_s3_bucket.kavinbucket,null_resource.image]
  bucket = aws_s3_bucket.kavinbucket.bucket
  acl = "public-read"
  key = "sample.png"
  source = "C:/Users/mukul jeveriya/Desktop/terraform/test/images/sample.png"
  
}

resource "aws_cloudfront_distribution" "kavins3" {
  origin {
    domain_name = aws_s3_bucket.kavinbucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }
  
  enabled = true
  default_root_object = "sample.png"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL certificate for the service.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "null_resource" "nullremote3" {
  depends_on = [aws_volume_attachment.ebs_attachment,aws_instance.myweb]
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/mukul jeveriya/Downloads/kavin-key.pem")
    host = aws_instance.myweb.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/kavinjaveriya/cloud.git /var/www/html/",
      "sudo su << EOF",
            "echo \"<img src=\"https://\"${aws_cloudfront_distribution.kavins3.domain_name}\"/sample.png\">\" >> /var/www/html/index.html",
            "EOF",
      "sudo systemctl restart httpd",      
    ]
  }
}

resource "null_resource" "nulllocal1"  {
  depends_on = [
    null_resource.nullremote3,
  ]

  provisioner "local-exec" {
    command = "start chrome  ${aws_instance.myweb.public_ip}"
  }
}