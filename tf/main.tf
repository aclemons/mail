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

resource "aws_s3_bucket" "caffe_mail" {
  bucket = "${local.project_name}-caffe"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "caffe_mail" {
  bucket = aws_s3_bucket.caffe_mail.id

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "caffe_mail" {
  bucket = aws_s3_bucket.caffe_mail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "miscellaneous" {
  bucket = aws_s3_bucket.caffe_mail.id

  policy = <<POLICY
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"IncomingSES",
      "Effect":"Allow",
      "Principal":{
        "Service":"ses.amazonaws.com"
      },
      "Action":"s3:PutObject",
      "Resource":"arn:aws:s3:::${aws_s3_bucket.caffe_mail.id}/*",
      "Condition":{
        "StringEquals":{
          "AWS:SourceAccount":"${data.aws_caller_identity.current.account_id}"
        }
      }
    }
  ]
}
POLICY
}

# IMAP FILTER

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

resource "aws_iam_policy" "lambda_ssm_policy" {
  name        = "${local.project_name}-lambda-ssm-policy"
  description = "Policy to attach to ${local.project_name} lambdas for access to ssm."

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

resource "aws_iam_role" "iam_for_imapfilter_lambda" {
  name               = "mail-imapfilter-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "imapfilter_lambda_basic_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.iam_for_imapfilter_lambda.id
}

resource "aws_iam_role_policy_attachment" "imapfilter_lambda_insights_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
  role       = aws_iam_role.iam_for_imapfilter_lambda.id
}

resource "aws_iam_role_policy_attachment" "imapfilter_ssm" {
  policy_arn = aws_iam_policy.lambda_ssm_policy.arn
  role       = aws_iam_role.iam_for_imapfilter_lambda.id
}

resource "aws_cloudwatch_log_group" "imapfilter_lambda" {
  name              = "/aws/lambda/${local.project_name}-imapfilter"
  retention_in_days = 14
}

resource "aws_lambda_function" "imapfilter_lambda" {
  function_name = "${local.project_name}-imapfilter"
  description   = "Run imapfilter to synchronise multiple email accounts and filter mails into directories."
  role          = aws_iam_role.iam_for_imapfilter_lambda.arn

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.imapfilter.repository_url}:${var.docker_image_version}"

  architectures = ["x86_64"]

  timeout = 60

  reserved_concurrent_executions = 1

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

# IMCOMING MAIL PROCESSOR

resource "aws_ecr_repository" "processor" {
  name                 = "${local.project_name}/processor"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "processor" {
  repository = aws_ecr_repository.processor.name

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

resource "aws_iam_role" "iam_for_processor_lambda" {
  name               = "mail-processor-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "processor_lambda_basic_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.iam_for_processor_lambda.id
}

resource "aws_iam_role_policy_attachment" "processor_lambda_insights_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
  role       = aws_iam_role.iam_for_processor_lambda.id
}

resource "aws_iam_role_policy_attachment" "processor_ssm" {
  policy_arn = aws_iam_policy.lambda_ssm_policy.arn
  role       = aws_iam_role.iam_for_processor_lambda.id
}

resource "aws_cloudwatch_log_group" "processor_lambda" {
  name              = "/aws/lambda/${local.project_name}-processor"
  retention_in_days = 14
}

resource "aws_lambda_function" "processor_lambda" {
  function_name = "${local.project_name}-processor"
  description   = "Process incoming mail from SES in the mail bucket."
  role          = aws_iam_role.iam_for_processor_lambda.arn

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.processor.repository_url}:${var.docker_image_version}"

  architectures = ["x86_64"]

  timeout = 30

  reserved_concurrent_executions = 1

  depends_on = [
    aws_cloudwatch_log_group.processor_lambda,
  ]

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.caffe_mail.id
    }
  }
}

resource "aws_ssm_parameter" "processor_imap_host" {
  name        = "/${local.project_name}/processor/imap_host"
  description = "IMAP Host for uploading incoming mail."
  type        = "SecureString"
  tier        = "Intelligent-Tiering"
  value       = "[]"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [value]
  }
}

resource "aws_ssm_parameter" "processor_imap_user" {
  name        = "/${local.project_name}/processor/imap_user"
  description = "IMAP user for uploading incoming mail."
  type        = "SecureString"
  tier        = "Intelligent-Tiering"
  value       = "[]"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [value]
  }
}

resource "aws_ssm_parameter" "processor_imap_pass" {
  name        = "/${local.project_name}/processor/imap_pass"
  description = "IMAP pass for uploading incoming mail."
  type        = "SecureString"
  tier        = "Intelligent-Tiering"
  value       = "[]"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [value]
  }
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id = "invoke-processor-for-incoming-mail"

  action         = "lambda:InvokeFunction"
  function_name  = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${aws_lambda_function.processor_lambda.function_name}"
  principal      = "s3.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = aws_s3_bucket.caffe_mail.arn
}

resource "aws_s3_bucket_notification" "incoming_mail_notification" {
  bucket = aws_s3_bucket.caffe_mail.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_iam_policy" "processor_lambda_s3_policy" {
  name        = "${local.project_name}-processor-lambda-s3-policy"
  description = "Policy to attach to ${local.project_name}-processor lambda for handling incoming mail data."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.caffe_mail.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "${aws_s3_bucket.caffe_mail.arn}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "processor_lambda_s3_policy" {
  policy_arn = aws_iam_policy.processor_lambda_s3_policy.arn
  role       = aws_iam_role.iam_for_processor_lambda.id
}

# in case we miss an event, also run once a day

resource "aws_cloudwatch_event_rule" "processor_cron" {
  name        = "${local.project_name}-processor-cron"
  description = "Invokes ${local.project_name}-processor Lambda function every day."

  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "processor" {
  rule = aws_cloudwatch_event_rule.processor_cron.id
  arn  = aws_lambda_function.processor_lambda.arn
}

resource "aws_lambda_permission" "processor_eventbridge" {
  function_name = "${local.project_name}-processor"
  statement_id  = "EventBridgePermissions"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.processor_cron.arn
}
