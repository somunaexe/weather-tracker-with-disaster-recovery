# after applying i need to update my domain registrar with these nameservers
# so that Route53 controls my DNS and the failover actually works
output "route53_nameservers" {
  value = aws_route53_zone.main.name_servers
}

output "route53_zone_id" {
  value = aws_route53_zone.main.zone_id
}

# useful for checking health check status in CloudWatch
output "health_check_id" {
  value = aws_route53_health_check.primary.id
}
