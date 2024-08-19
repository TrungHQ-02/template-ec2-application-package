variable "create_load_balancer" {
  description = "Boolean to determine if the load_balancer should be created."
  type        = bool
}

variable "load_balancer_type" {
  description = "The type of the Load Balancer."
  type        = string
  default     = "application"
}

variable "load_balancer_name" {
  description = "The name of the Load Balancer."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "load_balancer_subnet_ids" {
  description = "A list of subnet IDs for the Load Balancer."
  type        = list(string)
}

variable "load_balancer_internal" {
  description = "Boolean to determine if the Load Balancer is internal."
  type        = bool
}

variable "listener_port" {
  description = "The port on which the Load Balancer will listen."
  type        = number
}

variable "target_port" {
  description = "The port on the target instances that will receive traffic from the Load Balancer."
  type        = number
}

variable "protocol" {
  description = "The protocol used by the Load Balancer (e.g., HTTP, HTTPS)."
  type        = string
}

variable "asg_name" {
  description = "The name of the Auto Scaling Group."
  type        = string
}

variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group."
  type        = number
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group."
  type        = number
}

variable "asg_desire_capacity" {
  description = "Desired capacity of the Auto Scaling Group."
  type        = number
}

variable "asg_subnet_ids" {
  description = "A list of subnet IDs for the Auto Scaling Group."
  type        = list(string)
}

variable "scaling_policies" {
  description = "A map of scaling policies for the Auto Scaling Group."
  type        = any
  default     = {}
}

variable "launch_template_id" {
  description = "The ID of the launch template to use."
  type        = string
  default     = null
}

variable "create_launch_template" {
  description = "Boolean to determine if the launch template should be created."
  type        = bool
}

variable "launch_template_name" {
  description = "The name of the launch template."
  type        = string
}

variable "launch_template_description" {
  description = "A description for the launch template."
  type        = string
}

variable "ami" {
  description = "The AMI ID to use for the instances."
  type        = string
}

variable "instance_type" {
  description = "The instance type to use for the Auto Scaling Group."
  type        = string
}

variable "user_data" {
  description = "The user data to use for launch template."
  type        = string
  default     = null
}

variable "create_hosted_zone" {
  description = "Boolean to determine if the Route 53 hosted zone should be created."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name for Route 53 and ACM."
  type        = string
}

variable "domain_comment" {
  description = "A comment for the hosted zone."
  type        = string
}

variable "enable_https" {
  description = "Whether to enable HTTPS or not."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
