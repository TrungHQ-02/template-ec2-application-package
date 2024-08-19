output "route53_zone_zone_id" {
  description = "Zone ID of Route53 zone"
  value       = var.create ? aws_route53_zone.this[0].zone_id : null
}

output "route53_zone_zone_arn" {
  description = "Zone ARN of Route53 zone"
  value       = var.create ? aws_route53_zone.this[0].arn : null
}

output "route53_zone_name_servers" {
  description = "Name servers of Route53 zone"
  value       = var.create ? aws_route53_zone.this[0].name_servers : null
}

output "route53_zone_name" {
  description = "Name of Route53 zone"
  value       = var.create ? aws_route53_zone.this[0].name : null
}

output "route53_static_zone_name" {
  description = "Name of Route53 zone created statically"
  value       = var.create ? var.domain_name : null
}
