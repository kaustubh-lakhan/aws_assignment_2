

variable "vpc_id" {}
variable "public_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "target_instance_ids" { type = list(string) }
variable "acm_certificate_arn" { description = "The ARN of the SSL cert from ACM" }

# --- Application Load Balancer ---
resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false # Scheme: Internet-facing
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "main-alb"
  }
}

# --- Target Group ---
resource "aws_lb_target_group" "nginx_backend" {
  name     = "tg-ec2-nginx-backend"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200,301"
  }
}

# --- Register Targets (The 2 Private Instances) ---
resource "aws_lb_target_group_attachment" "backend_targets" {
  count            = length(var.target_instance_ids)
  target_group_arn = aws_lb_target_group.nginx_backend.arn
  target_id        = var.target_instance_ids[count.index]
  port             = 80
}

# --- Listener 1: HTTP (80) -> Redirect to HTTPS ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Standard security policy
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_backend.arn
  }
}

# Output the DNS name to access the application
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

