### Virtual Private Cloud

# Define either an existing VPC to create subnets in, or a CIDR block for a new VPC to create
# Done by checking if the "vpc" variable is a valid VPC ID (when using an existing VPC) or a valid CIDR (when creating a new one)
variable vpc {
	default = "10.0.0.0/16"
	description = "Enter an existing VPC ID to use it, or a valid CIDR block to create a new one."
	validation {
		# Must either start with "vpc-" or be a valid-format CIDR block
		# The validation does not check if the CIDR block regex values are valid, therefore inputs such as 999.999.999.999/99 are allowed
		# An incorrect value will still fail once the VPC module reads it
		condition = substr(var.vpc, 0, 4) == "vpc-" || can(regex("^\\d{1,3}(\\.\\d{1,3}){3}/\\d{1,2}$", var.vpc))
		error_message = "Value must be either a valid CIDR block or a VPC ID, starting with \"vpc-\"."
	}
}

# Retrieve an existing VPC, only if the "vpc" variable looks like a valid VPC ID
data aws_vpc this {
	count = substr(var.vpc, 0, 4) == "vpc-" ? 1 : 0
	id = var.vpc
}

# Create a new VPC, only if the "vpc" variable looks like a valid CIDR block
resource aws_vpc this {
	cidr_block = var.vpc
	count = can(regex("^\\d{1,3}(\\.\\d{1,3}){3}/\\d{1,2}$", var.vpc)) ? 1 : 0
	# tags
}

# This local is used to always point to the VPC object that other resources must use
# The value is the object of either the newly-created VPC (if it was created) or the existing VPC data source
# Used by all resources that must be placed within a VPC
locals {
	vpc = length(aws_vpc.this) == 1 ? aws_vpc.this[0] : data.aws_vpc.this[0]
}
