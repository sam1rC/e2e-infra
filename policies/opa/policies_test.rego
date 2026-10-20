package main

import rego.v1

full_tags := {
	"Project": "acme",
	"Environment": "dev",
	"Owner": "platform",
	"ManagedBy": "opentofu",
	"Blueprint": "ecommerce-t1",
	"CostCenter": "cc-1",
	"DataClassification": "internal",
}

rc(address, type, actions, after) := {
	"address": address,
	"mode": "managed",
	"type": type,
	"name": "this",
	"change": {"actions": actions, "after": after},
}

# --- Regla 1 -----------------------------------------------------------------

test_destroying_a_database_is_denied if {
	plan := {"resource_changes": [rc("aws_rds_cluster.this", "aws_rds_cluster", ["delete"], null)]}
	count(deny) == 1 with input as plan
}

test_replacing_a_table_is_denied if {
	plan := {"resource_changes": [rc("aws_dynamodb_table.this", "aws_dynamodb_table", ["delete", "create"], {})]}
	count(deny) == 1 with input as plan
}

test_replacing_create_before_destroy_is_denied if {
	plan := {"resource_changes": [rc("aws_kms_key.this", "aws_kms_key", ["create", "delete"], {})]}
	count(deny) == 1 with input as plan
}

test_allow_destroy_label_permits_destroy if {
	plan := {"resource_changes": [rc("aws_rds_cluster.this", "aws_rds_cluster", ["delete"], null)]}
	count(deny) == 0 with input as plan with data.allow_destroy as true
}

test_destroying_stateless_resource_is_allowed if {
	plan := {"resource_changes": [rc("aws_security_group.this", "aws_security_group", ["delete"], null)]}
	count(deny) == 0 with input as plan
}

test_updating_a_database_in_place_is_allowed if {
	plan := {"resource_changes": [rc("aws_db_instance.this", "aws_db_instance", ["update"], {"storage_encrypted": true, "publicly_accessible": false, "tags_all": full_tags})]}
	count(deny) == 0 with input as plan
}

# --- Regla 2 -----------------------------------------------------------------

test_open_ipv4_ingress_is_denied if {
	plan := {"resource_changes": [rc("aws_vpc_security_group_ingress_rule.a", "aws_vpc_security_group_ingress_rule", ["create"], {"cidr_ipv4": "0.0.0.0/0"})]}
	count(deny) == 1 with input as plan
}

test_open_ipv6_ingress_is_denied if {
	plan := {"resource_changes": [rc("aws_vpc_security_group_ingress_rule.a", "aws_vpc_security_group_ingress_rule", ["create"], {"cidr_ipv6": "::/0"})]}
	count(deny) == 1 with input as plan
}

test_sg_referenced_ingress_is_allowed if {
	plan := {"resource_changes": [rc("aws_vpc_security_group_ingress_rule.a", "aws_vpc_security_group_ingress_rule", ["create"], {"referenced_security_group_id": "sg-1"})]}
	count(deny) == 0 with input as plan
}

test_open_egress_is_not_flagged if {
	plan := {"resource_changes": [rc("aws_vpc_security_group_egress_rule.a", "aws_vpc_security_group_egress_rule", ["create"], {"cidr_ipv4": "0.0.0.0/0"})]}
	count(deny) == 0 with input as plan
}

# --- Regla 3 -----------------------------------------------------------------

test_missing_tag_is_denied if {
	tags := object.remove(full_tags, ["Owner"])
	plan := {"resource_changes": [rc("aws_sns_topic.this", "aws_sns_topic", ["create"], {"tags_all": tags})]}
	count(deny) == 1 with input as plan
}

test_all_required_tags_pass if {
	plan := {"resource_changes": [rc("aws_sns_topic.this", "aws_sns_topic", ["create"], {"tags_all": full_tags})]}
	count(deny) == 0 with input as plan
}

test_untaggable_resource_is_ignored if {
	plan := {"resource_changes": [rc("aws_s3_bucket_versioning.this", "aws_s3_bucket_versioning", ["create"], {"bucket": "x"})]}
	count(deny) == 0 with input as plan
}

# --- Regla 4 -----------------------------------------------------------------

test_public_database_is_denied if {
	plan := {"resource_changes": [rc("aws_db_instance.this", "aws_db_instance", ["create"], {"publicly_accessible": true, "storage_encrypted": true, "tags_all": full_tags})]}
	count(deny) == 1 with input as plan
}

test_unencrypted_cluster_is_denied if {
	plan := {"resource_changes": [rc("aws_rds_cluster.this", "aws_rds_cluster", ["create"], {"storage_encrypted": false, "tags_all": full_tags})]}
	count(deny) == 1 with input as plan
}

test_cluster_without_encryption_attribute_is_denied if {
	plan := {"resource_changes": [rc("aws_rds_cluster.this", "aws_rds_cluster", ["create"], {"tags_all": full_tags})]}
	count(deny) == 1 with input as plan
}

test_public_cluster_instance_is_denied if {
	plan := {"resource_changes": [rc("aws_rds_cluster_instance.this", "aws_rds_cluster_instance", ["create"], {"publicly_accessible": true, "tags_all": full_tags})]}
	count(deny) == 1 with input as plan
}

test_private_encrypted_database_passes if {
	plan := {"resource_changes": [rc("aws_db_instance.this", "aws_db_instance", ["create"], {"publicly_accessible": false, "storage_encrypted": true, "tags_all": full_tags})]}
	count(deny) == 0 with input as plan
}

# --- Regla 5 -----------------------------------------------------------------

bucket_change(addr, module_address) := object.union(
	rc(addr, "aws_s3_bucket", ["create"], {"tags_all": full_tags}),
	{"module_address": module_address},
)

test_bucket_without_public_access_block_is_denied if {
	plan := {
		"resource_changes": [rc("aws_s3_bucket.this", "aws_s3_bucket", ["create"], {"tags_all": full_tags})],
		"configuration": {"root_module": {"resources": []}},
	}
	count(deny) == 1 with input as plan
}

test_bucket_with_public_access_block_in_root_passes if {
	plan := {
		"resource_changes": [rc("aws_s3_bucket.this", "aws_s3_bucket", ["create"], {"tags_all": full_tags})],
		"configuration": {"root_module": {"resources": [{
			"type": "aws_s3_bucket_public_access_block",
			"expressions": {"bucket": {"references": ["aws_s3_bucket.this.id", "aws_s3_bucket.this"]}},
		}]}},
	}
	count(deny) == 0 with input as plan
}

test_bucket_with_public_access_block_in_module_passes if {
	plan := {
		"resource_changes": [bucket_change("module.bucket.aws_s3_bucket.this", "module.bucket")],
		"configuration": {"root_module": {"module_calls": {"bucket": {"module": {"resources": [{
			"type": "aws_s3_bucket_public_access_block",
			"expressions": {"bucket": {"references": ["aws_s3_bucket.this.id", "aws_s3_bucket.this"]}},
		}]}}}}},
	}
	count(deny) == 0 with input as plan
}

test_bucket_with_public_access_block_in_nested_module_passes if {
	plan := {
		"resource_changes": [bucket_change("module.a.module.b.aws_s3_bucket.this", "module.a.module.b")],
		"configuration": {"root_module": {"module_calls": {"a": {"module": {"module_calls": {"b": {"module": {"resources": [{
			"type": "aws_s3_bucket_public_access_block",
			"expressions": {"bucket": {"references": ["aws_s3_bucket.this[0].id", "aws_s3_bucket.this[0]", "aws_s3_bucket.this"]}},
		}]}}}}}}}},
	}
	count(deny) == 0 with input as plan
}

test_public_access_block_of_another_module_does_not_cover_bucket if {
	plan := {
		"resource_changes": [bucket_change("module.bucket.aws_s3_bucket.this", "module.bucket")],
		"configuration": {"root_module": {"module_calls": {"other": {"module": {"resources": [{
			"type": "aws_s3_bucket_public_access_block",
			"expressions": {"bucket": {"references": ["aws_s3_bucket.this.id", "aws_s3_bucket.this"]}},
		}]}}}}},
	}
	count(deny) == 1 with input as plan
}
