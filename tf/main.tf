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

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "mail-imapfilter-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.iam_for_lambda.id
}

resource "aws_iam_role_policy_attachment" "lambda_insights_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
  role       = aws_iam_role.iam_for_lambda.id
}

resource "aws_cloudwatch_log_group" "imapfilter_lambda" {
  name = "/aws/lambda/${local.project_name}-imapfilter"

  tags = {
    Project = local.project_name
  }
}

resource "aws_lambda_function" "imapfilter_lambda" {
  function_name = "${local.project_name}-imapfilter"
  description   = "Run imapfilter to synchronise multiple email accounts and filter mails into directories."
  role          = aws_iam_role.iam_for_lambda.arn

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.imapfilter.repository_url}:${var.docker_image_version}"

  timeout = 30

  tags = {
    Project = local.project_name
  }

  depends_on = [
    aws_cloudwatch_log_group.imapfilter_lambda,
  ]
}
