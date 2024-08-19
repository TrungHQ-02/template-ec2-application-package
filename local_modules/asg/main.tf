data "aws_partition" "current" {}

locals {
  create = var.create

  launch_template_name    = coalesce(var.launch_template_name, var.name)
  launch_template_id      = var.create && var.create_launch_template ? aws_launch_template.this[0].id : var.launch_template_id
  launch_template_version = var.create && var.create_launch_template && var.launch_template_version == null ? aws_launch_template.this[0].latest_version : var.launch_template_version

  asg_tags = merge(
    var.tags,
    { "Name" = coalesce(var.name, var.name) },
    var.autoscaling_group_tags,
  )
}

################################################################################
# Launch template
################################################################################

locals {
  iam_instance_profile_arn  = var.create_iam_instance_profile ? aws_iam_instance_profile.this[0].arn : var.iam_instance_profile_arn
  iam_instance_profile_name = !var.create_iam_instance_profile && var.iam_instance_profile_arn == null ? var.iam_instance_profile_name : null
}

resource "aws_launch_template" "this" {
  count = var.create && var.create_launch_template ? 1 : 0

  name        = var.launch_template_use_name_prefix ? null : local.launch_template_name
  name_prefix = var.launch_template_use_name_prefix ? "${local.launch_template_name}-" : null
  description = var.launch_template_description

  ebs_optimized = var.ebs_optimized
  image_id      = var.image_id
  key_name      = var.key_name
  user_data     = var.user_data

  vpc_security_group_ids = length(var.network_interfaces) > 0 ? [] : local.create_security_group ? concat(var.security_groups, [aws_security_group.this[0].id]) : var.security_groups

  default_version                      = var.default_version
  update_default_version               = var.update_default_version
  disable_api_termination              = var.disable_api_termination
  disable_api_stop                     = var.disable_api_stop
  instance_initiated_shutdown_behavior = var.instance_initiated_shutdown_behavior
  kernel_id                            = var.kernel_id
  ram_disk_id                          = var.ram_disk_id

  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings
    content {
      device_name  = block_device_mappings.value.device_name
      no_device    = try(block_device_mappings.value.no_device, null)
      virtual_name = try(block_device_mappings.value.virtual_name, null)

      dynamic "ebs" {
        for_each = flatten([try(block_device_mappings.value.ebs, [])])
        content {
          delete_on_termination = try(ebs.value.delete_on_termination, null)
          encrypted             = try(ebs.value.encrypted, null)
          kms_key_id            = try(ebs.value.kms_key_id, null)
          iops                  = try(ebs.value.iops, null)
          throughput            = try(ebs.value.throughput, null)
          snapshot_id           = try(ebs.value.snapshot_id, null)
          volume_size           = try(ebs.value.volume_size, null)
          volume_type           = try(ebs.value.volume_type, null)
        }
      }
    }
  }

  dynamic "cpu_options" {
    for_each = length(var.cpu_options) > 0 ? [var.cpu_options] : []
    content {
      core_count       = cpu_options.value.core_count
      threads_per_core = cpu_options.value.threads_per_core
    }
  }


  dynamic "iam_instance_profile" {
    for_each = local.iam_instance_profile_name != null || local.iam_instance_profile_arn != null ? [1] : []
    content {
      name = local.iam_instance_profile_name
      arn  = local.iam_instance_profile_arn
    }
  }

  instance_type = var.instance_type

  dynamic "monitoring" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      enabled = var.enable_monitoring
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

################################################################################
# IAM Role / Instance Profile
################################################################################

locals {
  internal_iam_instance_profile_name = try(coalesce(var.iam_instance_profile_name, var.iam_role_name), "")
}

data "aws_iam_policy_document" "assume_role_policy" {
  count = local.create && var.create_iam_instance_profile ? 1 : 0

  statement {
    sid     = "EC2AssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = local.create && var.create_iam_instance_profile ? 1 : 0

  name        = var.iam_role_use_name_prefix ? null : local.internal_iam_instance_profile_name
  name_prefix = var.iam_role_use_name_prefix ? "${local.internal_iam_instance_profile_name}-" : null
  path        = var.iam_role_path
  description = var.iam_role_description

  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy[0].json
  permissions_boundary  = var.iam_role_permissions_boundary
  force_detach_policies = true

  tags = merge(var.tags, var.iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = { for k, v in var.iam_role_policies : k => v if var.create && var.create_iam_instance_profile }

  policy_arn = each.value
  role       = aws_iam_role.this[0].name
}

resource "aws_iam_instance_profile" "this" {
  count = local.create && var.create_iam_instance_profile ? 1 : 0

  role = aws_iam_role.this[0].name

  name        = var.iam_role_use_name_prefix ? null : var.iam_role_name
  name_prefix = var.iam_role_use_name_prefix ? "${var.iam_role_name}-" : null
  path        = var.iam_role_path

  tags = merge(var.tags, var.iam_role_tags)
}

################################################################################
# Autoscaling group - default
################################################################################

resource "aws_autoscaling_group" "this" {
  count = local.create && !var.ignore_desired_capacity_changes ? 1 : 0

  name        = var.use_name_prefix ? null : var.name
  name_prefix = var.use_name_prefix ? "${var.name}-" : null

  dynamic "launch_template" {
    for_each = var.use_mixed_instances_policy ? [] : [1]

    content {
      id      = local.launch_template_id
      version = local.launch_template_version
    }
  }

  availability_zones  = var.availability_zones
  vpc_zone_identifier = var.vpc_zone_identifier

  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  desired_capacity_type     = var.desired_capacity_type
  capacity_rebalance        = var.capacity_rebalance
  min_elb_capacity          = var.min_elb_capacity
  wait_for_elb_capacity     = var.wait_for_elb_capacity
  wait_for_capacity_timeout = var.wait_for_capacity_timeout
  default_cooldown          = var.default_cooldown
  default_instance_warmup   = var.default_instance_warmup
  protect_from_scale_in     = var.protect_from_scale_in

  # TODO - remove at next breaking change. Use `traffic_source_identifier`/`traffic_source_type` instead
  load_balancers = var.load_balancers
  # TODO - remove at next breaking change. Use `traffic_source_identifier`/`traffic_source_type` instead
  target_group_arns         = var.target_group_arns
  placement_group           = var.placement_group
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  force_delete          = var.force_delete
  termination_policies  = var.termination_policies
  suspended_processes   = var.suspended_processes
  max_instance_lifetime = var.max_instance_lifetime

  enabled_metrics                  = var.enabled_metrics
  metrics_granularity              = var.metrics_granularity
  service_linked_role_arn          = var.service_linked_role_arn
  ignore_failed_scaling_activities = var.ignore_failed_scaling_activities

  dynamic "initial_lifecycle_hook" {
    for_each = var.initial_lifecycle_hooks
    content {
      name                    = initial_lifecycle_hook.value.name
      default_result          = try(initial_lifecycle_hook.value.default_result, null)
      heartbeat_timeout       = try(initial_lifecycle_hook.value.heartbeat_timeout, null)
      lifecycle_transition    = initial_lifecycle_hook.value.lifecycle_transition
      notification_metadata   = try(initial_lifecycle_hook.value.notification_metadata, null)
      notification_target_arn = try(initial_lifecycle_hook.value.notification_target_arn, null)
      role_arn                = try(initial_lifecycle_hook.value.role_arn, null)
    }
  }

  dynamic "instance_maintenance_policy" {
    for_each = length(var.instance_maintenance_policy) > 0 ? [var.instance_maintenance_policy] : []
    content {
      min_healthy_percentage = instance_maintenance_policy.value.min_healthy_percentage
      max_healthy_percentage = instance_maintenance_policy.value.max_healthy_percentage
    }
  }

  dynamic "instance_refresh" {
    for_each = length(var.instance_refresh) > 0 ? [var.instance_refresh] : []
    content {
      strategy = instance_refresh.value.strategy
      triggers = try(instance_refresh.value.triggers, null)

      dynamic "preferences" {
        for_each = try([instance_refresh.value.preferences], [])
        content {

          dynamic "alarm_specification" {
            for_each = try([preferences.value.alarm_specification], [])
            content {
              alarms = alarm_specification.value.alarms
            }
          }

          checkpoint_delay             = try(preferences.value.checkpoint_delay, null)
          checkpoint_percentages       = try(preferences.value.checkpoint_percentages, null)
          instance_warmup              = try(preferences.value.instance_warmup, null)
          min_healthy_percentage       = try(preferences.value.min_healthy_percentage, null)
          max_healthy_percentage       = try(preferences.value.max_healthy_percentage, null)
          auto_rollback                = try(preferences.value.auto_rollback, null)
          scale_in_protected_instances = try(preferences.value.scale_in_protected_instances, null)
          skip_matching                = try(preferences.value.skip_matching, null)
          standby_instances            = try(preferences.value.standby_instances, null)
        }
      }
    }
  }

  dynamic "mixed_instances_policy" {
    for_each = var.use_mixed_instances_policy ? [var.mixed_instances_policy] : []
    content {
      dynamic "instances_distribution" {
        for_each = try([mixed_instances_policy.value.instances_distribution], [])
        content {
          on_demand_allocation_strategy            = try(instances_distribution.value.on_demand_allocation_strategy, null)
          on_demand_base_capacity                  = try(instances_distribution.value.on_demand_base_capacity, null)
          on_demand_percentage_above_base_capacity = try(instances_distribution.value.on_demand_percentage_above_base_capacity, null)
          spot_allocation_strategy                 = try(instances_distribution.value.spot_allocation_strategy, null)
          spot_instance_pools                      = try(instances_distribution.value.spot_instance_pools, null)
          spot_max_price                           = try(instances_distribution.value.spot_max_price, null)
        }
      }

      launch_template {
        launch_template_specification {
          launch_template_id = local.launch_template_id
          version            = local.launch_template_version
        }

        dynamic "override" {
          for_each = try(mixed_instances_policy.value.override, [])

          content {
            dynamic "instance_requirements" {
              for_each = try([override.value.instance_requirements], [])

              content {
                dynamic "accelerator_count" {
                  for_each = try([instance_requirements.value.accelerator_count], [])

                  content {
                    max = try(accelerator_count.value.max, null)
                    min = try(accelerator_count.value.min, null)
                  }
                }

                accelerator_manufacturers = try(instance_requirements.value.accelerator_manufacturers, null)
                accelerator_names         = try(instance_requirements.value.accelerator_names, null)

                dynamic "accelerator_total_memory_mib" {
                  for_each = try([instance_requirements.value.accelerator_total_memory_mib], [])

                  content {
                    max = try(accelerator_total_memory_mib.value.max, null)
                    min = try(accelerator_total_memory_mib.value.min, null)
                  }
                }

                accelerator_types      = try(instance_requirements.value.accelerator_types, null)
                allowed_instance_types = try(instance_requirements.value.allowed_instance_types, null)
                bare_metal             = try(instance_requirements.value.bare_metal, null)

                dynamic "baseline_ebs_bandwidth_mbps" {
                  for_each = try([instance_requirements.value.baseline_ebs_bandwidth_mbps], [])

                  content {
                    max = try(baseline_ebs_bandwidth_mbps.value.max, null)
                    min = try(baseline_ebs_bandwidth_mbps.value.min, null)
                  }
                }

                burstable_performance                                   = try(instance_requirements.value.burstable_performance, null)
                cpu_manufacturers                                       = try(instance_requirements.value.cpu_manufacturers, null)
                excluded_instance_types                                 = try(instance_requirements.value.excluded_instance_types, null)
                instance_generations                                    = try(instance_requirements.value.instance_generations, null)
                local_storage                                           = try(instance_requirements.value.local_storage, null)
                local_storage_types                                     = try(instance_requirements.value.local_storage_types, null)
                max_spot_price_as_percentage_of_optimal_on_demand_price = try(instance_requirements.value.max_spot_price_as_percentage_of_optimal_on_demand_price, null)

                dynamic "memory_gib_per_vcpu" {
                  for_each = try([instance_requirements.value.memory_gib_per_vcpu], [])

                  content {
                    max = try(memory_gib_per_vcpu.value.max, null)
                    min = try(memory_gib_per_vcpu.value.min, null)
                  }
                }

                dynamic "memory_mib" {
                  for_each = try([instance_requirements.value.memory_mib], [])

                  content {
                    max = try(memory_mib.value.max, null)
                    min = try(memory_mib.value.min, null)
                  }
                }

                dynamic "network_bandwidth_gbps" {
                  for_each = try([instance_requirements.value.network_bandwidth_gbps], [])

                  content {
                    max = try(network_bandwidth_gbps.value.max, null)
                    min = try(network_bandwidth_gbps.value.min, null)
                  }
                }

                dynamic "network_interface_count" {
                  for_each = try([instance_requirements.value.network_interface_count], [])

                  content {
                    max = try(network_interface_count.value.max, null)
                    min = try(network_interface_count.value.min, null)
                  }
                }

                on_demand_max_price_percentage_over_lowest_price = try(instance_requirements.value.on_demand_max_price_percentage_over_lowest_price, null)
                require_hibernate_support                        = try(instance_requirements.value.require_hibernate_support, null)
                spot_max_price_percentage_over_lowest_price      = try(instance_requirements.value.spot_max_price_percentage_over_lowest_price, null)

                dynamic "total_local_storage_gb" {
                  for_each = try([instance_requirements.value.total_local_storage_gb], [])

                  content {
                    max = try(total_local_storage_gb.value.max, null)
                    min = try(total_local_storage_gb.value.min, null)
                  }
                }

                dynamic "vcpu_count" {
                  for_each = try([instance_requirements.value.vcpu_count], [])

                  content {
                    max = try(vcpu_count.value.max, null)
                    min = try(vcpu_count.value.min, null)
                  }
                }
              }
            }

            instance_type = try(override.value.instance_type, null)

            dynamic "launch_template_specification" {
              for_each = try([override.value.launch_template_specification], [])

              content {
                launch_template_id = try(launch_template_specification.value.launch_template_id, null)
              }
            }

            weighted_capacity = try(override.value.weighted_capacity, null)
          }
        }
      }
    }
  }

  dynamic "warm_pool" {
    for_each = length(var.warm_pool) > 0 ? [var.warm_pool] : []

    content {
      pool_state                  = try(warm_pool.value.pool_state, null)
      min_size                    = try(warm_pool.value.min_size, null)
      max_group_prepared_capacity = try(warm_pool.value.max_group_prepared_capacity, null)

      dynamic "instance_reuse_policy" {
        for_each = try([warm_pool.value.instance_reuse_policy], [])

        content {
          reuse_on_scale_in = try(instance_reuse_policy.value.reuse_on_scale_in, null)
        }
      }
    }
  }

  timeouts {
    delete = var.delete_timeout
  }

  dynamic "tag" {
    for_each = local.asg_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      load_balancers,
      target_group_arns,
    ]
  }
}

################################################################################
# Autoscaling group - ignore desired capacity
################################################################################

resource "aws_autoscaling_group" "idc" {
  count       = local.create && var.ignore_desired_capacity_changes ? 1 : 0
  depends_on  = [aws_launch_template.this]
  name        = var.use_name_prefix ? null : var.name
  name_prefix = var.use_name_prefix ? "${var.name}-" : null

  dynamic "launch_template" {
    for_each = var.use_mixed_instances_policy ? [] : [1]

    content {
      id      = local.launch_template_id
      version = local.launch_template_version
    }
  }

  availability_zones  = var.availability_zones
  vpc_zone_identifier = var.vpc_zone_identifier

  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  desired_capacity_type     = var.desired_capacity_type
  capacity_rebalance        = var.capacity_rebalance
  min_elb_capacity          = var.min_elb_capacity
  wait_for_elb_capacity     = var.wait_for_elb_capacity
  wait_for_capacity_timeout = var.wait_for_capacity_timeout
  default_cooldown          = var.default_cooldown
  default_instance_warmup   = var.default_instance_warmup
  protect_from_scale_in     = var.protect_from_scale_in

  load_balancers            = var.load_balancers
  target_group_arns         = var.target_group_arns
  placement_group           = var.placement_group
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  force_delete          = var.force_delete
  termination_policies  = var.termination_policies
  suspended_processes   = var.suspended_processes
  max_instance_lifetime = var.max_instance_lifetime

  enabled_metrics                  = var.enabled_metrics
  metrics_granularity              = var.metrics_granularity
  service_linked_role_arn          = var.service_linked_role_arn
  ignore_failed_scaling_activities = var.ignore_failed_scaling_activities

  dynamic "initial_lifecycle_hook" {
    for_each = var.initial_lifecycle_hooks
    content {
      name                    = initial_lifecycle_hook.value.name
      default_result          = try(initial_lifecycle_hook.value.default_result, null)
      heartbeat_timeout       = try(initial_lifecycle_hook.value.heartbeat_timeout, null)
      lifecycle_transition    = initial_lifecycle_hook.value.lifecycle_transition
      notification_metadata   = try(initial_lifecycle_hook.value.notification_metadata, null)
      notification_target_arn = try(initial_lifecycle_hook.value.notification_target_arn, null)
      role_arn                = try(initial_lifecycle_hook.value.role_arn, null)
    }
  }

  dynamic "instance_maintenance_policy" {
    for_each = length(var.instance_maintenance_policy) > 0 ? [var.instance_maintenance_policy] : []
    content {
      min_healthy_percentage = instance_maintenance_policy.value.min_healthy_percentage
      max_healthy_percentage = instance_maintenance_policy.value.max_healthy_percentage
    }
  }

  dynamic "instance_refresh" {
    for_each = length(var.instance_refresh) > 0 ? [var.instance_refresh] : []
    content {
      strategy = instance_refresh.value.strategy
      triggers = try(instance_refresh.value.triggers, null)

      dynamic "preferences" {
        for_each = try([instance_refresh.value.preferences], [])
        content {

          dynamic "alarm_specification" {
            for_each = try([preferences.value.alarm_specification], [])
            content {
              alarms = alarm_specification.value.alarms
            }
          }

          checkpoint_delay             = try(preferences.value.checkpoint_delay, null)
          checkpoint_percentages       = try(preferences.value.checkpoint_percentages, null)
          instance_warmup              = try(preferences.value.instance_warmup, null)
          min_healthy_percentage       = try(preferences.value.min_healthy_percentage, null)
          max_healthy_percentage       = try(preferences.value.max_healthy_percentage, null)
          auto_rollback                = try(preferences.value.auto_rollback, null)
          scale_in_protected_instances = try(preferences.value.scale_in_protected_instances, null)
          skip_matching                = try(preferences.value.skip_matching, null)
          standby_instances            = try(preferences.value.standby_instances, null)
        }
      }
    }
  }

  # dynamic "mixed_instances_policy" {
  #   for_each = var.use_mixed_instances_policy ? [var.mixed_instances_policy] : []
  #   content {
  #     dynamic "instances_distribution" {
  #       for_each = try([mixed_instances_policy.value.instances_distribution], [])
  #       content {
  #         on_demand_allocation_strategy            = try(instances_distribution.value.on_demand_allocation_strategy, null)
  #         on_demand_base_capacity                  = try(instances_distribution.value.on_demand_base_capacity, null)
  #         on_demand_percentage_above_base_capacity = try(instances_distribution.value.on_demand_percentage_above_base_capacity, null)
  #         spot_allocation_strategy                 = try(instances_distribution.value.spot_allocation_strategy, null)
  #         spot_instance_pools                      = try(instances_distribution.value.spot_instance_pools, null)
  #         spot_max_price                           = try(instances_distribution.value.spot_max_price, null)
  #       }
  #     }

  #     launch_template {
  #       launch_template_specification {
  #         launch_template_id = local.launch_template_id
  #         version            = local.launch_template_version
  #       }

  #       dynamic "override" {
  #         for_each = try(mixed_instances_policy.value.override, [])

  #         content {
  #           dynamic "instance_requirements" {
  #             for_each = try([override.value.instance_requirements], [])

  #             content {
  #               dynamic "accelerator_count" {
  #                 for_each = try([instance_requirements.value.accelerator_count], [])

  #                 content {
  #                   max = try(accelerator_count.value.max, null)
  #                   min = try(accelerator_count.value.min, null)
  #                 }
  #               }

  #               accelerator_manufacturers = try(instance_requirements.value.accelerator_manufacturers, null)
  #               accelerator_names         = try(instance_requirements.value.accelerator_names, null)

  #               dynamic "accelerator_total_memory_mib" {
  #                 for_each = try([instance_requirements.value.accelerator_total_memory_mib], [])

  #                 content {
  #                   max = try(accelerator_total_memory_mib.value.max, null)
  #                   min = try(accelerator_total_memory_mib.value.min, null)
  #                 }
  #               }

  #               accelerator_types      = try(instance_requirements.value.accelerator_types, null)
  #               allowed_instance_types = try(instance_requirements.value.allowed_instance_types, null)
  #               bare_metal             = try(instance_requirements.value.bare_metal, null)

  #               dynamic "baseline_ebs_bandwidth_mbps" {
  #                 for_each = try([instance_requirements.value.baseline_ebs_bandwidth_mbps], [])

  #                 content {
  #                   max = try(baseline_ebs_bandwidth_mbps.value.max, null)
  #                   min = try(baseline_ebs_bandwidth_mbps.value.min, null)
  #                 }
  #               }

  #               burstable_performance                                   = try(instance_requirements.value.burstable_performance, null)
  #               cpu_manufacturers                                       = try(instance_requirements.value.cpu_manufacturers, null)
  #               excluded_instance_types                                 = try(instance_requirements.value.excluded_instance_types, null)
  #               instance_generations                                    = try(instance_requirements.value.instance_generations, null)
  #               local_storage                                           = try(instance_requirements.value.local_storage, null)
  #               local_storage_types                                     = try(instance_requirements.value.local_storage_types, null)
  #               max_spot_price_as_percentage_of_optimal_on_demand_price = try(instance_requirements.value.max_spot_price_as_percentage_of_optimal_on_demand_price, null)

  #               dynamic "memory_gib_per_vcpu" {
  #                 for_each = try([instance_requirements.value.memory_gib_per_vcpu], [])

  #                 content {
  #                   max = try(memory_gib_per_vcpu.value.max, null)
  #                   min = try(memory_gib_per_vcpu.value.min, null)
  #                 }
  #               }

  #               dynamic "memory_mib" {
  #                 for_each = try([instance_requirements.value.memory_mib], [])

  #                 content {
  #                   max = try(memory_mib.value.max, null)
  #                   min = try(memory_mib.value.min, null)
  #                 }
  #               }

  #               dynamic "network_bandwidth_gbps" {
  #                 for_each = try([instance_requirements.value.network_bandwidth_gbps], [])

  #                 content {
  #                   max = try(network_bandwidth_gbps.value.max, null)
  #                   min = try(network_bandwidth_gbps.value.min, null)
  #                 }
  #               }

  #               dynamic "network_interface_count" {
  #                 for_each = try([instance_requirements.value.network_interface_count], [])

  #                 content {
  #                   max = try(network_interface_count.value.max, null)
  #                   min = try(network_interface_count.value.min, null)
  #                 }
  #               }

  #               on_demand_max_price_percentage_over_lowest_price = try(instance_requirements.value.on_demand_max_price_percentage_over_lowest_price, null)
  #               require_hibernate_support                        = try(instance_requirements.value.require_hibernate_support, null)
  #               spot_max_price_percentage_over_lowest_price      = try(instance_requirements.value.spot_max_price_percentage_over_lowest_price, null)

  #               dynamic "total_local_storage_gb" {
  #                 for_each = try([instance_requirements.value.total_local_storage_gb], [])

  #                 content {
  #                   max = try(total_local_storage_gb.value.max, null)
  #                   min = try(total_local_storage_gb.value.min, null)
  #                 }
  #               }

  #               dynamic "vcpu_count" {
  #                 for_each = try([instance_requirements.value.vcpu_count], [])

  #                 content {
  #                   max = try(vcpu_count.value.max, null)
  #                   min = try(vcpu_count.value.min, null)
  #                 }
  #               }
  #             }
  #           }

  #           instance_type = try(override.value.instance_type, null)

  #           dynamic "launch_template_specification" {
  #             for_each = try([override.value.launch_template_specification], [])

  #             content {
  #               launch_template_id = try(launch_template_specification.value.launch_template_id, null)
  #             }
  #           }

  #           weighted_capacity = try(override.value.weighted_capacity, null)
  #         }
  #       }
  #     }
  #   }
  # }

  # dynamic "warm_pool" {
  #   for_each = length(var.warm_pool) > 0 ? [var.warm_pool] : []

  #   content {
  #     pool_state                  = try(warm_pool.value.pool_state, null)
  #     min_size                    = try(warm_pool.value.min_size, null)
  #     max_group_prepared_capacity = try(warm_pool.value.max_group_prepared_capacity, null)

  #     dynamic "instance_reuse_policy" {
  #       for_each = try([warm_pool.value.instance_reuse_policy], [])

  #       content {
  #         reuse_on_scale_in = try(instance_reuse_policy.value.reuse_on_scale_in, null)
  #       }
  #     }
  #   }
  # }

  timeouts {
    delete = var.delete_timeout
  }

  dynamic "tag" {
    for_each = local.asg_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity,
      load_balancers,
      target_group_arns,
    ]
  }
}

################################################################################
# Autoscaling group schedule
################################################################################

resource "aws_autoscaling_schedule" "this" {
  for_each = local.create && var.create_schedule ? var.schedules : {}

  scheduled_action_name  = each.key
  autoscaling_group_name = try(aws_autoscaling_group.this[0].name, aws_autoscaling_group.idc[0].name)

  min_size         = try(each.value.min_size, null)
  max_size         = try(each.value.max_size, null)
  desired_capacity = try(each.value.desired_capacity, null)
  start_time       = try(each.value.start_time, null)
  end_time         = try(each.value.end_time, null)
  time_zone        = try(each.value.time_zone, null)

  # [Minute] [Hour] [Day_of_Month] [Month_of_Year] [Day_of_Week]
  # Cron examples: https://crontab.guru/examples.html
  recurrence = try(each.value.recurrence, null)
}

################################################################################
# Autoscaling Policy
################################################################################

resource "aws_autoscaling_policy" "this" {
  for_each = { for k, v in var.scaling_policies : k => v if local.create && var.create_scaling_policy }

  name                   = try(each.value.name, each.key)
  autoscaling_group_name = var.ignore_desired_capacity_changes ? aws_autoscaling_group.idc[0].name : aws_autoscaling_group.this[0].name

  adjustment_type           = try(each.value.adjustment_type, null)
  policy_type               = try(each.value.policy_type, null)
  estimated_instance_warmup = try(each.value.estimated_instance_warmup, null)
  cooldown                  = try(each.value.cooldown, null)
  min_adjustment_magnitude  = try(each.value.min_adjustment_magnitude, null)
  metric_aggregation_type   = try(each.value.metric_aggregation_type, null)
  scaling_adjustment        = try(each.value.scaling_adjustment, null)
  dynamic "step_adjustment" {
    for_each = try(each.value.step_adjustment, [])
    content {
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
      metric_interval_lower_bound = try(step_adjustment.value.metric_interval_lower_bound, null)
      metric_interval_upper_bound = try(step_adjustment.value.metric_interval_upper_bound, null)
    }
  }

  dynamic "target_tracking_configuration" {
    for_each = try([each.value.target_tracking_configuration], [])
    content {
      target_value     = target_tracking_configuration.value.target_value
      disable_scale_in = try(target_tracking_configuration.value.disable_scale_in, null)

      dynamic "predefined_metric_specification" {
        for_each = try([target_tracking_configuration.value.predefined_metric_specification], [])
        content {
          predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
          resource_label         = try(predefined_metric_specification.value.resource_label, null)
        }
      }

      dynamic "customized_metric_specification" {
        for_each = try([target_tracking_configuration.value.customized_metric_specification], [])

        content {
          dynamic "metric_dimension" {
            for_each = try([customized_metric_specification.value.metric_dimension], [])

            content {
              name  = metric_dimension.value.name
              value = metric_dimension.value.value
            }
          }

          metric_name = try(customized_metric_specification.value.metric_name, null)

          dynamic "metrics" {
            for_each = try(customized_metric_specification.value.metrics, [])

            content {
              expression = try(metrics.value.expression, null)
              id         = metrics.value.id
              label      = try(metrics.value.label, null)

              dynamic "metric_stat" {
                for_each = try([metrics.value.metric_stat], [])

                content {
                  dynamic "metric" {
                    for_each = try([metric_stat.value.metric], [])

                    content {
                      dynamic "dimensions" {
                        for_each = try(metric.value.dimensions, [])

                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }

                      metric_name = metric.value.metric_name
                      namespace   = metric.value.namespace
                    }
                  }

                  stat = metric_stat.value.stat
                  unit = try(metric_stat.value.unit, null)
                }
              }

              return_data = try(metrics.value.return_data, null)
            }
          }

          namespace = try(customized_metric_specification.value.namespace, null)
          statistic = try(customized_metric_specification.value.statistic, null)
          unit      = try(customized_metric_specification.value.unit, null)
        }
      }
    }
  }

  dynamic "predictive_scaling_configuration" {
    for_each = try([each.value.predictive_scaling_configuration], [])
    content {
      max_capacity_breach_behavior = try(predictive_scaling_configuration.value.max_capacity_breach_behavior, null)
      max_capacity_buffer          = try(predictive_scaling_configuration.value.max_capacity_buffer, null)
      mode                         = try(predictive_scaling_configuration.value.mode, null)
      scheduling_buffer_time       = try(predictive_scaling_configuration.value.scheduling_buffer_time, null)

      dynamic "metric_specification" {
        for_each = try([predictive_scaling_configuration.value.metric_specification], [])
        content {
          target_value = metric_specification.value.target_value

          dynamic "predefined_load_metric_specification" {
            for_each = try([metric_specification.value.predefined_load_metric_specification], [])
            content {
              predefined_metric_type = predefined_load_metric_specification.value.predefined_metric_type
              resource_label         = predefined_load_metric_specification.value.resource_label
            }
          }

          dynamic "predefined_metric_pair_specification" {
            for_each = try([metric_specification.value.predefined_metric_pair_specification], [])
            content {
              predefined_metric_type = predefined_metric_pair_specification.value.predefined_metric_type
              resource_label         = predefined_metric_pair_specification.value.resource_label
            }
          }



          dynamic "predefined_scaling_metric_specification" {
            for_each = try([metric_specification.value.predefined_scaling_metric_specification], [])
            content {
              predefined_metric_type = predefined_scaling_metric_specification.value.predefined_metric_type
              resource_label         = predefined_scaling_metric_specification.value.resource_label
            }
          }
        }
      }
    }
  }
}


################################################################################
# Security Group
################################################################################

locals {
  create_security_group = local.create && var.create_security_group
  security_group_name   = try(coalesce(var.security_group_name, var.name), "")
}

resource "aws_security_group" "this" {
  count = local.create_security_group ? 1 : 0

  name        = var.security_group_use_name_prefix ? null : local.security_group_name
  name_prefix = var.security_group_use_name_prefix ? "${local.security_group_name}-" : null
  description = coalesce(var.security_group_description, "Security group for ${var.name}")
  vpc_id      = var.vpc_id

  tags = merge(var.security_group_tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for k, v in var.security_group_egress_rules : k => v if local.create_security_group }

  # Required
  security_group_id = aws_security_group.this[0].id
  ip_protocol       = try(each.value.ip_protocol, "tcp")

  # Optional
  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6                    = lookup(each.value, "cidr_ipv6", null)
  description                  = try(each.value.description, null)
  from_port                    = try(each.value.from_port, null)
  prefix_list_id               = lookup(each.value, "prefix_list_id", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)
  to_port                      = try(each.value.to_port, null)

  tags = merge(var.security_group_tags, try(each.value.tags, {}))
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for k, v in var.security_group_ingress_rules : k => v if local.create_security_group }

  # Required
  security_group_id = aws_security_group.this[0].id
  ip_protocol       = try(each.value.ip_protocol, "tcp")

  # Optional
  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6                    = lookup(each.value, "cidr_ipv6", null)
  description                  = try(each.value.description, null)
  from_port                    = try(each.value.from_port, null)
  prefix_list_id               = lookup(each.value, "prefix_list_id", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)
  to_port                      = try(each.value.to_port, null)

  tags = merge(var.security_group_tags, try(each.value.tags, {}))
}


