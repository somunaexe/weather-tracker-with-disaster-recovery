# pings the EC2 every 30 seconds on port 80 at /health
resource "aws_route53_health_check" "primary" {
  ip_address        = var.ec2_public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name        = "${var.project_name}-primary-health-check"
    Environment = var.environment
  }
}

# DNS zone for my domain
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.project_name}-zone"
    Environment = var.environment
  }
}

# primary record at root domain - all traffic goes here normally
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
  ttl             = 60
  records         = [var.ec2_public_ip]
}

# secondary record - CNAME must be on a subdomain not the apex
# only gets traffic if primary health check fails
resource "aws_route53_record" "secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"
  ttl            = 60
  records        = [var.azure_app_url]
}

# fires when EC2 CPU goes above 80%
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${var.project_name}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "EC2 CPU usage is above 80%"

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = {
    Name        = "${var.project_name}-cpu-alarm"
    Environment = var.environment
  }
}

# fires when health check starts failing - means Azure failover is active
resource "aws_cloudwatch_metric_alarm" "health_check" {
  alarm_name          = "${var.project_name}-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Primary health check is failing - Azure failover may be active"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  tags = {
    Name        = "${var.project_name}-health-alarm"
    Environment = var.environment
  }
}
