output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "ec2_public_ip" {
  value = aws_eip.app.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.weather_data.bucket
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "ec2_instance_id" {
  value = aws_instance.app.id
}