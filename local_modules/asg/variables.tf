variable "launch_template_name" {
  description = "The name of the launch template."
  type        = string
  default     = null
}

variable "create_launch_template" {
  description = "Whether to create a new launch template."
  type        = bool
  default     = false
}

variable "autoscaling_group_tags" {
  description = "Tags to apply to the auto-scaling group."
  type        = map(string)
  default     = {}
}

variable "network_interfaces" {
  description = "List of network interfaces to attach to the instance."
  type = list(object({
    network_interface_id = string
    device_index         = number
  }))
  default = []
}

################################################################################
# Security Group
################################################################################

variable "create_security_group" {
  description = "Determines if a security group is created"
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Name to use on security group created"
  type        = string
  default     = null
}

variable "security_group_use_name_prefix" {
  description = "Determines whether the security group name (`security_group_name`) is used as a prefix"
  type        = bool
  default     = true
}

variable "security_group_description" {
  description = "Description of the security group created"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "Identifier of the VPC where the security group will be created"
  type        = string
  default     = null
}

variable "security_group_ingress_rules" {
  description = "Security group ingress rules to add to the security group created"
  type        = any
  default     = {}
}

variable "security_group_egress_rules" {
  description = "Security group egress rules to add to the security group created"
  type        = any
  default     = {}
}

variable "security_group_tags" {
  description = "A map of additional tags to add to the security group created"
  type        = map(string)
  default     = {}
}


variable "default_version" {
  description = "The default version of the launch template."
  type        = string
  default     = null
}

variable "update_default_version" {
  description = "Whether to update the default version of the launch template."
  type        = bool
  default     = false
}

variable "disable_api_termination" {
  description = "Whether to disable API termination for the instance."
  type        = bool
  default     = false
}

variable "disable_api_stop" {
  description = "Whether to disable API stop for the instance."
  type        = bool
  default     = false
}

variable "instance_initiated_shutdown_behavior" {
  description = "The instance initiated shutdown behavior."
  type        = string
  default     = "stop"
}

variable "kernel_id" {
  description = "The kernel ID to use for the instance."
  type        = string
  default     = null
}

variable "ram_disk_id" {
  description = "The RAM disk ID to use for the instance."
  type        = string
  default     = null
}

variable "block_device_mappings" {
  description = "Block device mappings for the instance."
  type = list(object({
    device_name  = string
    no_device    = string
    virtual_name = string
    ebs = list(object({
      delete_on_termination = bool
      encrypted             = bool
      kms_key_id            = string
      iops                  = number
      throughput            = number
      snapshot_id           = string
      volume_size           = number
      volume_type           = string
    }))
  }))
  default = []
}

variable "cpu_options" {
  description = "CPU options for the instance."
  type = object({
    core_count       = number
    threads_per_core = number
  })
  default = {
    core_count       = 1
    threads_per_core = 1
  }
}


variable "launch_template_description" {
  description = "The description of the launch template."
  type        = string
  default     = null
}

variable "launch_template_use_name_prefix" {
  description = "Whether to use a name prefix for the launch template."
  type        = bool
  default     = false
}


################################################################################
# IAM Role / Instance Profile
################################################################################

variable "create_iam_instance_profile" {
  description = "Determines whether an IAM instance profile is created or to use an existing IAM instance profile"
  type        = bool
  default     = false
}

variable "iam_instance_profile_arn" {
  description = "Amazon Resource Name (ARN) of an existing IAM instance profile. Used when `create_iam_instance_profile` = `false`"
  type        = string
  default     = null
}

variable "iam_instance_profile_name" {
  description = "The name of the IAM instance profile to be created (`create_iam_instance_profile` = `true`) or existing (`create_iam_instance_profile` = `false`)"
  type        = string
  default     = null
}

variable "iam_role_name" {
  description = "Name to use on IAM role created"
  type        = string
  default     = null
}

variable "iam_role_use_name_prefix" {
  description = "Determines whether the IAM role name (`iam_role_name`) is used as a prefix"
  type        = bool
  default     = true
}

variable "iam_role_path" {
  description = "IAM role path"
  type        = string
  default     = null
}

variable "iam_role_description" {
  description = "Description of the role"
  type        = string
  default     = null
}

variable "iam_role_permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for the IAM role"
  type        = string
  default     = null
}

variable "iam_role_policies" {
  description = "IAM policies to attach to the IAM role"
  type        = map(string)
  default     = {}
}

variable "iam_role_tags" {
  description = "A map of additional tags to add to the IAM role created"
  type        = map(string)
  default     = {}
}

################################################################################
# Autoscaling group
################################################################################

variable "create" {
  description = "Determines whether to create autoscaling group or not"
  type        = bool
  default     = true
}

variable "ignore_desired_capacity_changes" {
  description = "Determines whether the `desired_capacity` value is ignored after initial apply. See README note for more details"
  type        = bool
  default     = false
}

variable "name" {
  description = "Name used across the resources created"
  type        = string
}

variable "use_name_prefix" {
  description = "Determines whether to use `name` as is or create a unique name beginning with the `name` as the prefix"
  type        = bool
  default     = true
}

variable "instance_name" {
  description = "Name that is propogated to launched EC2 instances via a tag - if not provided, defaults to `var.name`"
  type        = string
  default     = ""
}

variable "launch_template_id" {
  description = "ID of an existing launch template to be used (created outside of this module)"
  type        = string
  default     = null
}

variable "launch_template_version" {
  description = "Launch template version. Can be version number, `$Latest`, or `$Default`"
  type        = string
  default     = null
}

variable "availability_zones" {
  description = "A list of one or more availability zones for the group. Used for EC2-Classic and default subnets when not specified with `vpc_zone_identifier` argument. Conflicts with `vpc_zone_identifier`"
  type        = list(string)
  default     = null
}

variable "vpc_zone_identifier" {
  description = "A list of subnet IDs to launch resources in. Subnets automatically determine which availability zones the group will reside. Conflicts with `availability_zones`"
  type        = list(string)
  default     = null
}

variable "min_size" {
  description = "The minimum size of the autoscaling group"
  type        = number
  default     = null
}

variable "max_size" {
  description = "The maximum size of the autoscaling group"
  type        = number
  default     = null
}

variable "desired_capacity" {
  description = "The number of Amazon EC2 instances that should be running in the autoscaling group"
  type        = number
  default     = null
}

variable "desired_capacity_type" {
  description = "The unit of measurement for the value specified for desired_capacity. Supported for attribute-based instance type selection only. Valid values: `units`, `vcpu`, `memory-mib`."
  type        = string
  default     = null
}

variable "capacity_rebalance" {
  description = "Indicates whether capacity rebalance is enabled"
  type        = bool
  default     = null
}

variable "min_elb_capacity" {
  description = "Setting this causes Terraform to wait for this number of instances to show up healthy in the ELB only on creation. Updates will not wait on ELB instance number changes"
  type        = number
  default     = null
}

variable "wait_for_elb_capacity" {
  description = "Setting this will cause Terraform to wait for exactly this number of healthy instances in all attached load balancers on both create and update operations. Takes precedence over `min_elb_capacity` behavior."
  type        = number
  default     = null
}

variable "wait_for_capacity_timeout" {
  description = "A maximum duration that Terraform should wait for ASG instances to be healthy before timing out. (See also Waiting for Capacity below.) Setting this to '0' causes Terraform to skip all Capacity Waiting behavior."
  type        = string
  default     = null
}

variable "default_cooldown" {
  description = "The amount of time, in seconds, after a scaling activity completes before another scaling activity can start"
  type        = number
  default     = null
}

variable "default_instance_warmup" {
  description = "Amount of time, in seconds, until a newly launched instance can contribute to the Amazon CloudWatch metrics. This delay lets an instance finish initializing before Amazon EC2 Auto Scaling aggregates instance metrics, resulting in more reliable usage data. Set this value equal to the amount of time that it takes for resource consumption to become stable after an instance reaches the InService state."
  type        = number
  default     = null
}

variable "protect_from_scale_in" {
  description = "Allows setting instance protection. The autoscaling group will not select instances with this setting for termination during scale in events."
  type        = bool
  default     = false
}

variable "load_balancers" {
  description = "A list of elastic load balancer names to add to the autoscaling group names. Only valid for classic load balancers. For ALBs, use `target_group_arns` instead"
  type        = list(string)
  default     = []
}

variable "target_group_arns" {
  description = "A set of `aws_alb_target_group` ARNs, for use with Application or Network Load Balancing"
  type        = list(string)
  default     = []
}

variable "placement_group" {
  description = "The name of the placement group into which you'll launch your instances, if any"
  type        = string
  default     = null
}

variable "health_check_type" {
  description = "`EC2` or `ELB`. Controls how health checking is done"
  type        = string
  default     = null
}

variable "health_check_grace_period" {
  description = "Time (in seconds) after instance comes into service before checking health"
  type        = number
  default     = null
}

variable "force_delete" {
  description = "Allows deleting the Auto Scaling Group without waiting for all instances in the pool to terminate. You can force an Auto Scaling Group to delete even if it's in the process of scaling a resource. Normally, Terraform drains all the instances before deleting the group. This bypasses that behavior and potentially leaves resources dangling"
  type        = bool
  default     = null
}

variable "termination_policies" {
  description = "A list of policies to decide how the instances in the Auto Scaling Group should be terminated. The allowed values are `OldestInstance`, `NewestInstance`, `OldestLaunchConfiguration`, `ClosestToNextInstanceHour`, `OldestLaunchTemplate`, `AllocationStrategy`, `Default`"
  type        = list(string)
  default     = []
}

variable "suspended_processes" {
  description = "A list of processes to suspend for the Auto Scaling Group. The allowed values are `Launch`, `Terminate`, `HealthCheck`, `ReplaceUnhealthy`, `AZRebalance`, `AlarmNotification`, `ScheduledActions`, `AddToLoadBalancer`, `InstanceRefresh`. Note that if you suspend either the `Launch` or `Terminate` process types, it can prevent your Auto Scaling Group from functioning properly"
  type        = list(string)
  default     = []
}

variable "max_instance_lifetime" {
  description = "The maximum amount of time, in seconds, that an instance can be in service, values must be either equal to 0 or between 86400 and 31536000 seconds"
  type        = number
  default     = null
}

variable "enabled_metrics" {
  description = "A list of metrics to collect. The allowed values are `GroupDesiredCapacity`, `GroupInServiceCapacity`, `GroupPendingCapacity`, `GroupMinSize`, `GroupMaxSize`, `GroupInServiceInstances`, `GroupPendingInstances`, `GroupStandbyInstances`, `GroupStandbyCapacity`, `GroupTerminatingCapacity`, `GroupTerminatingInstances`, `GroupTotalCapacity`, `GroupTotalInstances`"
  type        = list(string)
  default     = []
}

variable "metrics_granularity" {
  description = "The granularity to associate with the metrics to collect. The only valid value is `1Minute`"
  type        = string
  default     = null
}

variable "service_linked_role_arn" {
  description = "The ARN of the service-linked role that the ASG will use to call other AWS services"
  type        = string
  default     = null
}

variable "initial_lifecycle_hooks" {
  description = "One or more Lifecycle Hooks to attach to the Auto Scaling Group before instances are launched. The syntax is exactly the same as the separate `aws_autoscaling_lifecycle_hook` resource, without the `autoscaling_group_name` attribute. Please note that this will only work when creating a new Auto Scaling Group. For all other use-cases, please use `aws_autoscaling_lifecycle_hook` resource"
  type        = list(map(string))
  default     = []
}

variable "instance_refresh" {
  description = "If this block is configured, start an Instance Refresh when this Auto Scaling Group is updated"
  type        = any
  default     = {}
}

variable "use_mixed_instances_policy" {
  description = "Determines whether to use a mixed instances policy in the autoscaling group or not"
  type        = bool
  default     = false
}

variable "mixed_instances_policy" {
  description = "Configuration block containing settings to define launch targets for Auto Scaling groups"
  type        = any
  default     = null
}

variable "delete_timeout" {
  description = "Delete timeout to wait for destroying autoscaling group"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "warm_pool" {
  description = "If this block is configured, add a Warm Pool to the specified Auto Scaling group"
  type        = any
  default     = {}
}

variable "ebs_optimized" {
  description = "If true, the launched EC2 instance will be EBS-optimized"
  type        = bool
  default     = null
}

variable "image_id" {
  description = "The AMI from which to launch the instance"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "The type of the instance. If present then `instance_requirements` cannot be present"
  type        = string
  default     = null
}

variable "instance_requirements" {
  description = "The attribute requirements for the type of instance. If present then `instance_type` cannot be present"
  type        = any
  default     = {}
}

variable "key_name" {
  description = "The key name that should be used for the instance"
  type        = string
  default     = null
}

variable "user_data" {
  description = "The Base64-encoded user data to provide when launching the instance"
  type        = string
  default     = null
}

variable "security_groups" {
  description = "A list of security group IDs to associate"
  type        = list(string)
  default     = []
}

variable "enable_monitoring" {
  description = "Enables/disables detailed monitoring"
  type        = bool
  default     = true
}

variable "metadata_options" {
  description = "Customize the metadata options for the instance"
  type        = map(string)
  default     = {}
}

variable "ignore_failed_scaling_activities" {
  description = "Whether to ignore failed Auto Scaling scaling activities while waiting for capacity. The default is false -- failed scaling activities cause errors to be returned."
  type        = bool
  default     = false
}

variable "instance_maintenance_policy" {
  description = "If this block is configured, add a instance maintenance policy to the specified Auto Scaling group"
  type        = map(any)
  default     = {}
}

################################################################################
# Autoscaling group schedule
################################################################################

variable "create_schedule" {
  description = "Determines whether to create autoscaling group schedule or not"
  type        = bool
  default     = true
}

variable "schedules" {
  description = "Map of autoscaling group schedule to create"
  type        = map(any)
  default     = {}
}

################################################################################
# Autoscaling policy
################################################################################

variable "create_scaling_policy" {
  description = "Determines whether to create target scaling policy schedule or not"
  type        = bool
  default     = true
}

variable "scaling_policies" {
  description = "Map of target scaling policy schedule to create"
  type        = any
  default     = {}
}