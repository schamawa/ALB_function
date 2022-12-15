provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "test_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "vpc"
  }
}

##########Subnet ap-south-1a######################################

resource "aws_subnet" "test_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  count                   = 2
  cidr_block              = element(var.subnet_cidr, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = "true"

  tags = {
    Name = "${element(var.azs, count.index)}"
  }
}



################ IGW ################################################

resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "test_IGW"
  }
}

##################### Route_Table ######################################

resource "aws_route_table" "test_rt" {
  count  = 2
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # All resources in public subnet are accessible from all internet.
    gateway_id = aws_internet_gateway.test_igw.id
  }

  tags = {
    Name = "Public-route"
  }
}

resource "aws_route_table_association" "test_rta" {
  count          = 2
  route_table_id = element(aws_route_table.test_rt.*.id, count.index)
  subnet_id      = element(aws_subnet.test_subnet.*.id, count.index)
}





################ Security_Group ###############################################

resource "aws_security_group" "test_sg" {
  name   = "test_sg"
  vpc_id = aws_vpc.test_vpc.id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test_sg"
  }

}

##############################EC2 Instance ###############################################

resource "aws_instance" "test_ec2" {
  count         = 2
  ami           = var.image_id # ap-south1
  subnet_id     = element(aws_subnet.test_subnet.*.id, count.index)
  instance_type = var.instance_type
  security_groups = [aws_security_group.test_sg.id]

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<h1>Hello World from $(hostname -f) in AZ $EC2_AVAIL_ZONE </h1>" > /var/www/html/index.html
EOF


  tags = {
    Name = "test-ec2"
  }


}






 

####################Application Load Balancer #########################

resource "aws_lb_target_group" "test-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "test-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.test_vpc.id
}


resource "aws_lb_target_group_attachment" "test-alb-target-group-attachment1" {
  count            = 2
  target_group_arn = "${aws_lb_target_group.test-target-group.arn}"
  target_id        = element(aws_instance.test_ec2.*.id, count.index)
  port             = 80
}




resource "aws_lb" "test-aws-alb" {
  name     = "test-test-alb"
  internal = false

  security_groups = [aws_security_group.test_sg.id]

  subnets = aws_subnet.test_subnet.*.id

  tags = {
    Name = "test-alb"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}


resource "aws_lb_listener" "test-alb-listner" {
  load_balancer_arn = "${aws_lb.test-aws-alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.test-target-group.arn}"
  }
}
