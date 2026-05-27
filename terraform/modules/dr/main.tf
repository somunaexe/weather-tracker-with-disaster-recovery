# ─── HEALTH CHECKS ──────────────────────────────────────

# pings the EC2 every 30 seconds on port 80 at /health
# if it fails 3 times in a row, Route53 switches to Azure
resource "aws_route53_health_check" "primary" {
  fqdn              = var.ec2_public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/health" # my app needs to expose this endpoint
  failure_threshold = "3"       # 3 consecutive failures triggers failover
  request_interval  = "30"      # checks every 30 seconds

  tags = {
    Name        = "${var.project_name}-primary-health-check"
    Environment = var.environment
  }
}

# ─── ROUTE53 DNS ────────────────────────────────────────

# the DNS zone for my domain - like a phonebook for my app
# after applying, i need to point my domain's nameservers to these
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.project_name}-zone"
    Environment = var.environment
  }
}

# primary DNS record - normally all traffic goes here (AWS EC2)
# Route53 only stops using this if the health check above fails
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
  ttl             = 60        # DNS refreshes every 60 seconds
  records         = [var.ec2_public_ip]
}

# secondary DNS record - only gets traffic if primary health check fails
# this is what makes the disaster recovery actually work
resource "aws_route53_record" "secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "CNAME"

  failover_routing_policy {
    type = "SECONDARY"  # sits on standby until AWS goes down
  }

  set_identifier = "secondary"
  ttl            = 60
  records        = [var.azure_app_url]  # points to Azure as the backup
}

# ─── CLOUDWATCH ALARMS ──────────────────────────────────

# fires when EC2 CPU goes above 80% for 2 consecutive 2-minute periods
# good early warning that the server is struggling before it actually goes down
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${var.project_name}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"    # has to be high for 2 periods in a row
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"  # each period is 2 minutes
  statistic           = "Average"
  threshold           = "80"   # alert if CPU goes above 80%
  alarm_description   = "EC2 CPU usage is above 80%"

  dimensions = {
    InstanceId = var.ec2_instance_id  # watches my specific EC2 instance
  }

  tags = {
    Name        = "${var.project_name}-cpu-alarm"
    Environment = var.environment
  }
}

# fires when the health check above starts failing
# this is how i know Azure failover has kicked in
resource "aws_cloudwatch_metric_alarm" "health_check" {
  alarm_name          = "${var.project_name}-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"    # 1 = healthy, 0 = failed
  alarm_description   = "Primary health check is failing - Azure failover may be active"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  tags = {
    Name        = "${var.project_name}-health-alarm"
    Environment = var.environment
  }
}
