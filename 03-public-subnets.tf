### Public subnets

# Define a map with subnet CIDR blocks as keys and the availability zone to use for each subnet as the corresponding value
# Used to create public subnets and all related resources
variable public_subnets {
	default = {}
	type = map(string)
}

# Create a local to be used by other resources
locals {
	public_subnets = var.public_subnets
}

# Create public subnets
resource aws_subnet public {
	availability_zone = values(local.public_subnets)[count.index]
	cidr_block = keys(local.public_subnets)[count.index]
	count = length(local.public_subnets)
	# tags = {
	# 	"Name" = format("%s%s%s", data.aws_default_tags.default_tags.tags["Name"], "-public-", substr(values(local.public_subnets)[count.index], -2, 2))
	# }
	vpc_id = local.vpc.id
}

# Create a public route table if an internet gateway exists to associate it with
# Done by checking if any public subnets have been declared, since an IGW is not created/data sourced without them
resource aws_route_table to_internet_gateway {
	count = length(local.public_subnets) == 0 ? 0 : 1
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = local.internet_gateway.id
	}
	# tags
	vpc_id = local.vpc.id
}

# Associate the public route table, if it's created, with each public subnet
resource aws_route_table_association to_internet_gateway {
	count = length(aws_route_table.to_internet_gateway) == 0 ? 0 : length(local.public_subnets)
	route_table_id = aws_route_table.to_internet_gateway[0].id
	subnet_id = aws_subnet.public[count.index].id
}
