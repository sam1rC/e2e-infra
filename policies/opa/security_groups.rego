package main

import rego.v1

# Regla 2: ninguna regla de entrada abierta a Internet.
open_cidrs := {"0.0.0.0/0", "::/0"}

deny contains msg if {
	some rc in surviving_changes
	rc.type == "aws_vpc_security_group_ingress_rule"
	some field in ["cidr_ipv4", "cidr_ipv6"]
	rc.change.after[field] in open_cidrs
	msg := sprintf("%s permite entrada desde %s; referencia otro security group o una prefix list", [rc.address, rc.change.after[field]])
}
