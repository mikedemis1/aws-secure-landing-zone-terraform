# Only values that actually differ between a fork of this repo and this one.
# A variable for a value that never changes is noise; ports, retention days and
# the like stay hardcoded on purpose.

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Prefix for resource names and the Project tag."
  type        = string
  default     = "secure-landing-zone"
}

variable "vpc_cidr" {
  description = "VPC address space. Changing it replaces the whole VPC; it exists for reuse, not for editing in place."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }

  validation {
    # Subnets are carved as /24s (8 extra bits). Anything smaller than /20 would
    # produce subnets below AWS's /28 floor.
    condition     = tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be /20 or larger so that /24 subnets can be carved from it."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread each tier across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3."
  }

  validation {
    condition     = var.az_count <= length(data.aws_availability_zones.available.names)
    error_message = "az_count exceeds the availability zones present in the selected region."
  }
}
