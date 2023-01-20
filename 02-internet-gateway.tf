### Internet gateway

# Retrieve information of an existing internet gateway
# Done by checking if any public subnets should be provisioned, and if the target is an existing VPC
data aws_internet_gateway this {
	count = length(local.public_subnets) == 0 ? 0 : (length(data.aws_vpc.this) == 1 ? 1 : 0)
	filter {
		name = "attachment.vpc-id"
		values = [local.vpc.id]
	}
}

# Create a new internet gateway if a new VPC is being created as well
# Done by checking if any public subnets have been declared and if a new VPC is being provisioned
resource aws_internet_gateway this {
	count = length(local.public_subnets) == 0 ? 0 : (length(aws_vpc.this) == 1 ? 1 : 0)
	# tags
	vpc_id = local.vpc.id
}

# This local points to an internet gateway object
# Used by public subnets and public subnet route tables to determine whether they should be created (as public subnets, by definition, cannot fulfill their role without an internet gateway)
# Done by constructing an internet gateway-based object with a subset of attributes that we require from it
# It is done this way due to the fact that the resource object outputs different attributes compared to a data source object of the same resource type
# Workaround taken from here:
# https://github.com/hashicorp/terraform/issues/22713#issuecomment-528979215
# Value set to null when a new VPC is created, but an internet gateway is not, which happens only when there are no public subnets
# Otherwise, either the newly created internet gateway's attributes are used if it exists, or the attributes are taken from the internet gateway data source object
locals {
	internet_gateway = length(aws_internet_gateway.this) == 0 ? (length(data.aws_internet_gateway.this) == 0 ? null : {
		id = data.aws_internet_gateway.this[0].id
	}) : {
		id = aws_internet_gateway.this[0].id
	}
}
