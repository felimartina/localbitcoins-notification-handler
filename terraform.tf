terraform {
  backend "s3" {
    bucket  = "felimartina.terraform"
    key     = "localbtc-notification-handler-jccastagno/envs/dev/terraform.tfstate"
    region  = "us-east-1"
    profile = "pipe"
  }
}

provider "aws" {
  profile = "pipe"
  region  = "${var.REGION}"
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config {
    bucket  = "felimartina.terraform"
    key     = "localbtc-notification-handler-jccastagno/envs/dev/terraform.tfstate"
    region  = "us-east-1"
    profile = "pipe"
  }
}

# Zip up Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "function"
  output_path = "${var.LAMBDA_ZIP_NAME}"
}

# Role for Lambda function
resource "aws_iam_role" "localbtc_notification_handler_lambda_role" {
  name = "${var.APP_NAME}-lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# IAM Policy for Lambda function
resource "aws_iam_role_policy" "localbtc_notification_handler_lambda_role_policy" {
  name = "${var.APP_NAME}-lambda-role-policy"
  role = "${aws_iam_role.localbtc_notification_handler_lambda_role.id}"

  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [{
    "Sid": "WriteLogsToCloudWatch",
      "Effect" : "Allow",
      "Action" : [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource" : "arn:aws:logs:*:*:*"
    }, {
      "Sid": "SendSms",
      "Effect" : "Allow",
      "Action" : [
        "sns:Publish"
      ],
      "Resource" : "*"
    }
  ]
}
EOF
}

# Lambda function
resource "aws_lambda_function" "localbtc_notification_handler_lambda" {
  filename         = "${var.LAMBDA_ZIP_NAME}"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  description      = "Lambda Function that sends an SMS notification when a notification in localbitcoins.com is received."
  function_name    = "${var.APP_NAME}-lambda"
  role             = "${aws_iam_role.localbtc_notification_handler_lambda_role.arn}"
  handler          = "index.handler"
  runtime          = "python2.7"
  timeout          = "30"

  environment {
    variables = {
      LBC_HMAC_KEY              = "${var.LBC_HMAC_KEY}"
      LBC_HMAC_SECRET           = "${var.LBC_HMAC_SECRET}"
      PHONE_NUMBERS             = "${var.PHONE_NUMBERS}"
      ACCOUNT                   = "${var.ACCOUNT}"
      AUTOMATED_MESSAGE_ENGLISH = "${var.AUTOMATED_MESSAGE_ENGLISH}"
      AUTOMATED_MESSAGE_SPANISH = "${var.AUTOMATED_MESSAGE_SPANISH}"
      NEW_OFFER_SMS_TEMPLATE    = "${var.NEW_OFFER_SMS_TEMPLATE}"
    }
  }
}

# Alias pointing to $LATEST for Lambda function
resource "aws_lambda_alias" "localbtc_notification_handler_lambda_alias" {
  name             = "Latest"
  function_name    = "${aws_lambda_function.localbtc_notification_handler_lambda.arn}"
  function_version = "$LATEST"
}

# Allow Cloudwatch to invoke Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.localbtc_notification_handler_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.scheduled_event.arn}"
  qualifier     = "${aws_lambda_alias.localbtc_notification_handler_lambda_alias.name}"
}

# Create event rule
resource "aws_cloudwatch_event_rule" "scheduled_event" {
  name                = "${var.APP_NAME}-scheduled-event"
  description         = "Recurrent event for calling Lambda Function"
  schedule_expression = "${var.SCHEDULE_EXPRESSION}"
}

# Map event rule to trigger lambda function
resource "aws_cloudwatch_event_target" "lambda_trigger" {
  rule = "${aws_cloudwatch_event_rule.scheduled_event.name}"
  arn  = "${aws_lambda_alias.localbtc_notification_handler_lambda_alias.arn}"
}
