resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = local.name })
}

# Cierra el security group por defecto (control EC2.2 de Security Hub): sin reglas de entrada ni de salida.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${local.name}-default-closed" })
}

resource "aws_internet_gateway" "this" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_subnet" "public" {
  for_each = local.public_azs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = local.subnet_cidrs["public"][each.key]
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${local.name}-public-${each.key}", Tier = "public" })
}

resource "aws_subnet" "app" {
  for_each = local.app_azs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = local.subnet_cidrs["app"][each.key]

  tags = merge(var.tags, { Name = "${local.name}-app-${each.key}", Tier = "app" })
}

resource "aws_subnet" "data" {
  for_each = local.data_azs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = local.subnet_cidrs["data"][each.key]

  tags = merge(var.tags, { Name = "${local.name}-data-${each.key}", Tier = "data" })
}
