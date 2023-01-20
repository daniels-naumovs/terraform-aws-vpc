### Create private subnets and associated resources

# Set a public NAT gateway configuration
# Used to select whether to provision either:
# * no public NAT gateways (for private subnets with no internet access)
# * one public NAT gateway (for outbound-only internet access through a single public NAT gateway)
# * multiple public NAT gateways (same as with one public NAT gateway, but with added redundancy in case a public NAT gateway fails)
# Used by the local with the same name to determine how many public NAT gateways must be provisioned
variable public_nat_gateway_count {
	default = 0
	type = number
	description = "Number of public NAT gateways. Must not be greater than the number of private subnets"
	sensitive = false
}

# Same notes as "var.public_subnets" apply
variable private_subnets {
	default = {}
	type = map(string)
}

locals {
	# This local is used to determine the number of public NAT gateways to be created
	# Used by public NAT gateways and associated resources
	# One private subnet does not need more than one public NAT gateway, this number is set to the number of private subnets if it exceeds it
	public_nat_gateway_count = var.public_nat_gateway_count > length(local.private_subnets) ? length(local.private_subnets) : var.public_nat_gateway_count

	# This local is used by the AWS subnet and route table association resources
	# Used to determine subnet CIDRs, availability zones and the number of required subnet associations
	private_subnets = var.private_subnets
}

# Create private subnets
resource aws_subnet private {
	availability_zone = values(local.private_subnets)[count.index]
	cidr_block = keys(local.private_subnets)[count.index]
	count = length(local.private_subnets)
	# tags = {
	# 	"Name" = format("%s%s%s", data.aws_default_tags.default_tags.tags["Name"], "-private-", substr(values(local.private_subnets)[count.index], -2, 2))
	# }
	vpc_id = local.vpc.id
}

# Create elastic IPs
# Used by public NAT gateways
resource aws_eip this {
	count = local.public_nat_gateway_count
	# tags = {
	# 	Name = aws_subnet.private[count.index].tags["Name"]
	# }
	vpc = true
}

# Create public NAT gateways to allow private subnets to access the internet, but not vice-versa
resource aws_nat_gateway public {
	allocation_id = aws_eip.this[count.index].id
	count = local.public_nat_gateway_count
	# If there are more public NAT gateways than there are subnets, multiple public NAT gateways will be placed in a single subnet
	subnet_id = aws_subnet.pub[count.index % length(local.public_subnets)].id
	# tags = {
	# 	Name = aws_eip.this[count.index].tags["Name"]
	# }
}

# Create a public route table per public NAT gateway
# This table routes traffic not intercepted by previous rules, if any, to a public NAT gateway
resource aws_route_table to_public_nat_gateway {
	count = local.public_nat_gateway_count
	route {
		cidr_block = "0.0.0.0/0"
		nat_gateway_id = aws_nat_gateway.public[count.index].id
	}
	# tags = {
	# 	Name = aws_nat_gateway.public[count.index].tags["Name"]
	# }
	vpc_id = local.vpc.id
}

# Associate a public route table with a private subnet
# In other words, assign a public route table to a private subnet
resource aws_route_table_association to_public_nat_gateway {
	count = length(aws_route_table.to_public_nat_gateway) == 0 ? 0 : length(local.private_subnets)
	route_table_id = aws_route_table.to_public_nat_gateway[count.index % length(aws_route_table.to_public_nat_gateway)].id
	subnet_id = aws_subnet.private[count.index].id
}
