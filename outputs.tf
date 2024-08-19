# output "load_balancer_target_groups" {
#   value = var.create_load_balancer == true && var.load_balancer_type == "application" ? module.alb.target_group_arns : module.nlb.target_group_arns
# }
