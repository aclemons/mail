locals {
  project_name = "mail"
}

resource "aws_ses_domain_identity" "caffe" {
  domain = "caffe.nz"
}

resource "aws_ses_domain_dkim" "caffe" {
  domain = aws_ses_domain_identity.caffe.domain
}

resource "aws_ses_domain_mail_from" "caffe" {
  domain           = aws_ses_domain_identity.caffe.domain
  mail_from_domain = "mail.${aws_ses_domain_identity.caffe.domain}"
}

resource "aws_ecr_repository" "imapfilter" {
  name                 = "${local.project_name}/imapfilter"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "imapfilter" {
  repository = aws_ecr_repository.imapfilter.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Delete untagged images.",
            "selection": {
                "tagStatus": "untagged",
                "countType": "imageCountMoreThan",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Keep that last 2 git sha tagged images (last 2 merges to master).",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["git"],
                "countType": "imageCountMoreThan",
                "countNumber": 2
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
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

resource "aws_iam_policy" "imapfilter_lambda" {
  name        = "${local.project_name}-imapfilter-lambda-ssm-policy"
  description = "Policy to attach to ${local.project_name}-imapfilter lambda."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${local.project_name}*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = aws_iam_policy.imapfilter_lambda.arn
  role       = aws_iam_role.iam_for_lambda.id
}

resource "aws_cloudwatch_log_group" "imapfilter_lambda" {
  name = "/aws/lambda/${local.project_name}-imapfilter"
}

resource "aws_lambda_function" "imapfilter_lambda" {
  function_name = "${local.project_name}-imapfilter"
  description   = "Run imapfilter to synchronise multiple email accounts and filter mails into directories."
  role          = aws_iam_role.iam_for_lambda.arn

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.imapfilter.repository_url}:${var.docker_image_version}"

  timeout = 30

  depends_on = [
    aws_cloudwatch_log_group.imapfilter_lambda,
  ]
}

resource "aws_ssm_parameter" "accounts_data" {
  name        = "/${local.project_name}/imapfilter/accounts"
  description = "JSON payload of all the account information"
  type        = "SecureString"
  tier        = "Intelligent-Tiering"
  value       = "[]"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [value]
  }
}

resource "aws_cloudwatch_event_rule" "cron" {
  name        = "${local.project_name}-imapfilter-cron"
  description = "Invokes ${local.project_name}-imapfilter Lambda function every 5 minutes."

  schedule_expression = "cron(*/5 * ? * * *)" # every 5 minutes
}

resource "aws_cloudwatch_event_target" "imapfilter" {
  rule = aws_cloudwatch_event_rule.cron.id
  arn  = aws_lambda_function.imapfilter_lambda.arn
}

resource "aws_lambda_permission" "imapfilter_eventbridge" {
  function_name = "${local.project_name}-imapfilter"
  statement_id  = "EventBridgePermissions"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron.arn
}
