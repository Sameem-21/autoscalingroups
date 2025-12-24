#configuring the provider 
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"


    }
  }
}
#configuring the region
provider "aws" {
  region = "ap-south-1"
}
#creating VPC network
resource "aws_vpc" "demo-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "demo-vpc"
  }
}
#adding subnets to the vpc in different availability zones
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public_subnet_1"
  }
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "public_subnet_2"
  }
}

#creating internet gateway

resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo-vpc.id
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "demo_igw"
  }
}

#   creating route table
resource "aws_route_table" "demo_route_table" {
  vpc_id = aws_vpc.demo-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "demo_route_table"
  }
}

#creating route table association with subnet
resource "aws_route_table_association" "demo_route_table_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.demo_route_table.id
}

resource "aws_route_table_association" "demo_route_table_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.demo_route_table.id
}


#creating security group

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "sallowing http, https"
  vpc_id      = aws_vpc.demo-vpc.id

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "alb-sg"
  }

}

#creating ingress rules for security group

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
# resource "aws_vpc_security_group_egress_rule" "allow_ssh" {
#   security_group_id = aws_security_group.alb_sg.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 22
#   to_port           = 22
#   ip_protocol       = "tcp"
# }

#creating egress rule for security group    
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#creating another security group for EC2 instances  

resource "aws_security_group" "ec2_app_sg" {
  name        = "ec2-app-sg"
  description = "allowing traffic from ALB SG"
  vpc_id      = aws_vpc.demo-vpc.id

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "ec2-app-sg"
  }

}

#creating ingress rule for the security group to allow traffic from ALB security group
resource "aws_vpc_security_group_ingress_rule" "allow_from_alb_sg" {


  security_group_id            = aws_security_group.ec2_app_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id #referncing alb_sg as the source
  from_port                    = 80
  to_port                      = 80 #0 to 65535 means all ports
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_alb_sg" {
  security_group_id = aws_security_group.ec2_app_sg.id
  #referenced_security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4   = "49.207.186.200/32"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "ec2_allow_all_outbound" {
  security_group_id = aws_security_group.ec2_app_sg.id
  #referenced_security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
#creatinh IAM Instance profile
# 1. Create IAM role for EC2
resource "random_pet" "suffix" {}
resource "aws_iam_role" "ec2_role" {
  name = "ec2-ssm-role-${random_pet.suffix.id}"

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
  lifecycle {
    create_before_destroy = true 
  }
}
# 2. Attach AmazonSSMManagedInstanceCore policy
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# 3. Create instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-role-${random_pet.suffix.id}"
  role = aws_iam_role.ec2_role.name
}



#creating launch template

resource "aws_launch_template" "web_launch_template" {
  name = "asg-launch-template"
  #template_version= "Latest"
  #version = "$latest"
  image_id      = "ami-02d26659fd82cf299" #Amazon ubuntu AMI (HVM), SSD Volume Type
  instance_type = "t3.micro"
  key_name      = "test_apsouth1" #replace with your key pair name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_app_sg.id] #vpc_security_group_ids = [aws_security_group.ec2_app_sg.id] #attaching the security group created for ec2 instances
  }


  #paste my iam instance profile here
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }


  user_data = filebase64("${path.root}/htmldata.sh") #using user data to install httpd and start  service

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg-launch-template"
    }

  }
}
output "launch_template" {
  value       = aws_launch_template.web_launch_template.name
  description = "The name of the launch template"
}

#target group creation for ALB
resource "aws_lb_target_group" "web_target_group" {
  name     = "asg-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo-vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "asg-target-group"
  }
}
output "target_group" {
  value       = aws_lb_target_group.web_target_group.name
  description = "The name of the target group"
}

#creating application load balancer
resource "aws_lb" "app_load_balancer" {
  name                       = "app-load-balancer"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]                                 #attaching the security group created for ALB
  subnets                    = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id] #attaching the public subnets created
  enable_deletion_protection = false
  lifecycle {
    create_before_destroy = true 
  }

  tags = {
    Name = "app-load-balancer"
  }
}
output "load_balancer" {
  value       = aws_lb.app_load_balancer.name
  description = "The name of the load balancer"
}

# Create a listener for the Application Load Balancer
resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.app_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}
##to get the output of the DNS name of the load balancer. to check my code is working or not
output "dns_name" {
  value       = aws_lb.app_load_balancer.dns_name
  description = "The DNS name of the load balancer"

}


#creating auto scaling group
resource "aws_autoscaling_group" "demo-asg" {
  name = "demo-asg"
  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id] #attaching the public subnets created
  max_size            = 4
  min_size            = 1
  desired_capacity    = 3
  target_group_arns   = [aws_lb_target_group.web_target_group.arn]
  instance_maintenance_policy {
    min_healthy_percentage = 0
    max_healthy_percentage = 100 #terminate and launch
  }

}
resource "aws_autoscaling_policy" "target_tracking_cpu" {
  name                   = "Target Tracking Policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.demo-asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value     = 50 # Target average CPU utilization (%)
    disable_scale_in = false
    #estimated_instance_warmup = 300  # seconds
  }
}





