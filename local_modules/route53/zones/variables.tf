variable "create" {
  description = "Whether to create the Route 53 zone."
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "The name of the hosted zone."
  type        = string
}

variable "comment" {
  description = "A comment about the hosted zone."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Whether to allow deletion of the zone even if it contains records."
  type        = bool
  default     = false
}

variable "delegation_set_id" {
  description = "The ID of the delegation set to use for the zone."
  type        = string
  default     = null
}

variable "vpc" {
  description = "A list of VPCs associated with the hosted zone."
  type = list(object({
    vpc_id     = string
    vpc_region = string
  }))
  default = []
}

variable "tags" {
  description = "A map of tags to assign to the resource."
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional tags to add to the resource."
  type        = map(string)
  default     = {}
}
