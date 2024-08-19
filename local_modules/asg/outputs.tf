output "launch_template_id" {
  value = var.create && var.create_launch_template ? aws_launch_template.this[0].id : null
}

output "scaling_policies" {
  value = var.create && var.create_scaling_policy ? aws_autoscaling_policy.this : null
}