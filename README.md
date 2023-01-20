# VPC module

This module provisions the following resources:
* virtual private cloud
* internet gateway
* public subnets
  * route tables
  * route table associations
* private subnets
  * elastic IP addresses
  * public NAT gateways
  * route tables
  * route table associations

This module provisions a new Virtual Private Cloud if `var.vpc` is set to a
valid CIDR block and, with it, an internet gateway if the module is also set to
create at least one public subnet via `var.public_subnets`. Alternatively, if
`var.vpc` is set to a VPC ID, the module will fetch data for an exsiting VPC and
internet gateway based on the VPC ID.

An internet gateway will not be provisioned or sourced if `var.public_subnets` is
empty. This is because, without needing internet access, there is no point in
provisioning an internet gateway.

If `var.public_subnets` is not empty, the module will provision all of the subnets
in that map, create a public route table with a route to the internet gateway
from all addresses and create a route table association with each public subnet.
If `var.private_subnets` is not empty, private subnets will be created in the VPC.

If `var.public_nat_gateway_count` is greater than zero, the module will create
that many public NAT gateways, as well as an elastic IP address linked to each,
distributed evenly across all the public subnets, starting with the first one in
the list. If you would like the NAT gateways to be placed in specific public
subnets, put the public subnets that you want NAT Gateways in as the first
entries in `var.public_subnets`.

The module will never create more public NAT Gateways than private subnets since
*all* traffic outside of the VPC is routed through the NAT Gateways, not taking
into account custom rules outside of this module added to the NAT Gateways. If
`var.public_nat_gateway_count` is larger than the number of private subnets, the
module will override the value to be equal to that of the number of private
subnets. The module will then create one Route Table per public NAT Gateway with
a route to that gateway from all addresses and associate every private subnet
with one of the gateways.

# Variables

| Name | Type | Usage | Example |
|---|---|---|---|
| `public_nat_gateway_count` | number | Number of public NAT gateways to provision. Cannot exceed the number of items in `var.private_subnets` | `0`, `1`, `length(var.private_subnets)` |
| `public_subnets` | map(string) | Map of subnet CIDR blocks as keys and its availability zone as the respective value. All AZs must be from the same region | `{}`, `{"10.0.0.0/24": "eu-west-1a", "10.0.1.0/24": "eu-west-1b"}` |
| `private_subnets` | map(string) | See `var.public_subnets` | See `var.public_subnets` |
| `vpc` | string | Either a CIDR block for creating a new VPC or the ID of an existing VPC to use. Existing VPCs *must* have an internet gateway attached if `var.public_subnets` contains at least one item | `10.0.0.0/16`, `vpc-abcdef123456` |

# Example usage

```terraform
module example {
	source = "./path/to/module"
	public_nat_gateway_count = 1
	public_subnets = {
		"10.0.0.0/24": "eu-west-1a"
	}
	private_subnets = {
		"10.0.1.0/24": "eu-west-1a"
	}
	vpc = "vpc-abcdef123456"
}
```

# Future considerations/features/improvements

* Add the AWS IAM permissions required to provision each resource
* Add private NAT gateways
* Add module outputs
* improve `var.vpc` CIDR block regex; make sure all values are valid, i.e. 0 <=
x <= 255 for each address number or 16 <= x <= 28 for mask
* improve `var.vpc` VPC ID validation; find out what & how many characters can
there be after "vpc-" and convert the substr function to a `can(regex())`
* add proper tags
* add VPC/Subnet logging via Flow Logs
* allow naming the resources
* accept `list(string)` for `var.public_subnets` and `var.private_subnets`, where the
list contains only keys (subnet CIDRs) and all available AZs are selected
round-robin, much like how `var.public_nat_gateway_count` works
