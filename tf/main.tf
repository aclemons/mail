locals {
  project_name  = "mail"
}

resource "aws_ecr_repository" "imapfilter" {
  name                 = "${local.project_name}/imapfilter"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = local.project_name
  }
}
