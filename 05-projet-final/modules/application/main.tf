terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 6.0"
    }
  }
}

variable "nom" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnets_publics" {
  type = list(string)
}

variable "subnets_prives" {
  type = list(string)
}

variable "type_instance" {
  type    = string
  default = "t3.micro"
}

variable "capacite" {
  type = object({
    min     = number
    max     = number
    desired = number
  })
  default = { min = 1, max = 2, desired = 1 }

  validation {
    condition     = var.capacite.min <= var.capacite.desired && var.capacite.desired <= var.capacite.max
    error_message = "Il faut min <= desired <= max."
  }
}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.nom}-alb-"
  vpc_id      = var.vpc_id

  # dynamic block : une règle ingress par port
  dynamic "ingress" {
    for_each = toset([80])
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instances" {
  name_prefix = "${var.nom}-app-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # seul l'ALB peut joindre les instances
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  name               = var.nom
  load_balancer_type = "application"
  subnets            = var.subnets_publics
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "this" {
  name     = var.nom
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_launch_template" "this" {
  name_prefix            = "${var.nom}-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.type_instance
  vpc_security_group_ids = [aws_security_group.instances.id]

  # IMDSv2 obligatoire, disque chiffré : bonnes pratiques sécurité
  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      encrypted   = true
    }
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    dnf install -y nginx
    echo "Bonjour depuis $(hostname) - ${var.nom}" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT
  )
}

resource "aws_autoscaling_group" "this" {
  name                = var.nom
  min_size            = var.capacite.min
  max_size            = var.capacite.max
  desired_capacity    = var.capacite.desired
  vpc_zone_identifier = var.subnets_prives
  target_group_arns   = [aws_lb_target_group.this.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
  }

  lifecycle {
    ignore_changes = [desired_capacity] # géré par l'autoscaling
  }
}

output "url" {
  value = "http://${aws_lb.this.dns_name}"
}
