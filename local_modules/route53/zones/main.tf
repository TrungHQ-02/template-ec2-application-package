resource "aws_route53_zone" "this" {
  count = var.create ? 1 : 0

  name          = var.domain_name
  comment       = var.comment
  force_destroy = var.force_destroy

  delegation_set_id = var.delegation_set_id

  dynamic "vpc" {
    for_each = try(tolist(var.vpc), [var.vpc])

    content {
      vpc_id     = vpc.value.vpc_id
      vpc_region = lookup(vpc.value, "vpc_region", null)
    }
  }

  tags = merge(
    var.tags,
    var.additional_tags
  )
}
