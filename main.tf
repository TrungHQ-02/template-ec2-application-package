locals {
  tags = var.tags
}

##################################################################
# Application Load Balancer
##################################################################
module "alb" {
  source                     = "./local_modules/elb"
  create                     = var.create_load_balancer == true && var.load_balancer_type == "application" ? true : false
  name                       = var.load_balancer_name
  vpc_id                     = var.vpc_id
  subnets                    = var.load_balancer_subnet_ids
  internal                   = var.load_balancer_internal
  load_balancer_type         = var.load_balancer_type
  enable_deletion_protection = false

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  client_keep_alive = 7200

  # the listener default action should be: redirect, forward, redirect
  listeners = {
    default_listener = {
      port     = var.listener_port
      protocol = var.protocol

      fixed_response = {
        content_type = "text/plain"
        message_body = "Fixed message"
        status_code  = "200"
      }

      # rules
      rules = {
        ex-forward = {
          actions = [{
            type             = "forward"
            target_group_key = "ex-instance"
          }]

          conditions = [{
            path_pattern = {
              values = ["/"]
            }
          }]
        }
      }
    }
  }

  target_groups = {
    ex-instance = {
      name_prefix                       = "h1"
      protocol                          = var.protocol
      port                              = var.target_port
      target_type                       = "instance"
      deregistration_delay              = 10
      load_balancing_algorithm_type     = "weighted_random"
      load_balancing_anomaly_mitigation = "on"
      load_balancing_cross_zone_enabled = false

      target_group_health = {
        dns_failover = {
          minimum_healthy_targets_count = 2
        }
        unhealthy_state_routing = {
          minimum_healthy_targets_percentage = 50
        }
      }

      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = var.protocol
        matcher             = "200-399"
      }

      protocol_version = "HTTP1"
      tags             = merge(local.tags, {})
    }

  }

  tags = merge(local.tags, {})
}


##################################################################
# Network Load Balancer
##################################################################
module "nlb" {
  source                     = "./local_modules/elb"
  create                     = var.create_load_balancer == true && var.load_balancer_type == "network" ? true : false
  name                       = var.load_balancer_name
  vpc_id                     = var.vpc_id
  subnets                    = var.load_balancer_subnet_ids
  internal                   = var.load_balancer_internal
  load_balancer_type         = var.load_balancer_type
  enable_deletion_protection = false
  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  client_keep_alive = 7200

  # the listener default action should be: redirect, forward, redirect
  listeners = {
    default_listener = {
      port     = var.listener_port
      protocol = var.protocol

      forward = {
        target_group_key = "ex-instance"
      }

      # rules
    }
  }

  target_groups = {
    ex-instance = {
      name_prefix          = "h1"
      protocol             = var.protocol
      port                 = var.target_port
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
      }

      tags = merge(local.tags, {})
    }

  }

  tags = merge(local.tags, {})
}

################################################################################
# ASG
################################################################################
module "asg" {
  depends_on        = [module.nlb, module.alb]
  source            = "./local_modules/asg"
  name              = var.asg_name
  create            = true
  target_group_arns = var.load_balancer_type == "application" ? module.alb.target_group_arns : module.nlb.target_group_arns

  # Auto Scaling Group
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desire_capacity
  vpc_zone_identifier = var.asg_subnet_ids

  # Scaling policies
  create_scaling_policy = true
  scaling_policies      = var.scaling_policies

  # Launch template
  launch_template_id              = var.launch_template_id
  create_launch_template          = var.create_launch_template
  launch_template_version         = "$Latest"
  launch_template_name            = var.launch_template_name
  launch_template_description     = var.launch_template_description
  launch_template_use_name_prefix = true
  image_id                        = var.ami
  instance_type                   = var.instance_type
  ebs_optimized                   = true
  user_data                       = base64encode(var.user_data)

  # Security Group
  vpc_id = var.vpc_id
  security_group_ingress_rules = {
    all_http = {
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      description                  = "HTTP web traffic"
      referenced_security_group_id = var.load_balancer_type == "application" ? module.alb.security_group_id : module.nlb.security_group_id

    }
    all_https = {
      from_port                    = 443
      to_port                      = 443
      ip_protocol                  = "tcp"
      description                  = "HTTPS web traffic"
      referenced_security_group_id = var.load_balancer_type == "application" ? module.alb.security_group_id : module.nlb.security_group_id
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = { for k, v in var.scaling_policies : k => v if v.policy_type != "TargetTrackingScaling" }

  alarm_name                = each.value.metric_alarm.alarm_name
  comparison_operator       = each.value.metric_alarm.comparison_operator
  evaluation_periods        = each.value.metric_alarm.evaluation_periods
  metric_name               = each.value.metric_alarm.metric_name
  namespace                 = try(each.value.metric_alarm.namespace, "AWS/EC2")
  period                    = try(each.value.metric_alarm.period, 300)
  statistic                 = try(each.value.metric_alarm.statistic, "Average")
  extended_statistic        = try(each.value.metric_alarm.extended_statistic, null)
  threshold                 = try(each.value.metric_alarm.threshold, 70)
  treat_missing_data        = try(each.value.metric_alarm.treat_missing_data, "missing")
  ok_actions                = try(each.value.metric_alarm.ok_actions, [])
  insufficient_data_actions = try(each.value.metric_alarm.insufficient_data_actions, [])
  dimensions = {
    try(each.value.metric_alarm.dimensions_name, "AutoScalingGroupName") = try(each.value.metric_alarm.dimensions_target, each.value.name)
  }

  alarm_description = try(each.value.metric_alarm.alarm_description, "Default description")
  alarm_actions     = try([lookup(module.asg.scaling_policies, each.value.name).arn], [])
  tags              = merge(local.tags, {})
}

################################################################################
# Route 53 + ACM
################################################################################
module "zones" {
  source        = "./local_modules/route53/zones"
  create        = var.create_hosted_zone
  domain_name   = var.domain_name
  comment       = var.domain_comment
  force_destroy = false

  tags = merge(local.tags, {})
}

module "records" {
  source    = "./local_modules/route53/records"
  create    = true
  zone_name = module.zones.route53_zone_name
  records = [
    {
      name    = "lb"
      type    = "CNAME"
      records = var.load_balancer_type == "application" ? [module.alb.dns_name] : [module.nlb.dns_name]
      ttl     = 3600
    },
  ]

  depends_on = [module.zones]
}

module "acm" {
  source              = "./local_modules/acm"
  create_certificate  = var.create_load_balancer == true && var.create_hosted_zone == true && var.enable_https ? true : false
  domain_name         = var.domain_name
  zone_id             = module.zones.route53_zone_zone_id
  validation_method   = "DNS"
  wait_for_validation = true
  depends_on          = [module.zones]
  tags                = merge(local.tags, {})
}