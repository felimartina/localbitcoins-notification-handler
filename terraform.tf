# Variables that need to exist in a different file
variable "ACCESS_KEY" {}
variable "SECRET_KEY" {}
variable "LBC_HMAC_KEY" {}
variable "LBC_HMAC_SECRET" {}
variable "PHONE_NUMBER" {}
variable "REGION" {
  default = "us-east-1"
}
variable "APP_NAME" {
  default = "localbtc-notification-handler"
}
variable "SCHEDULE_EXPRESSION" {
  default = "rate(5 minutes)"
}
variable "LAMBDA_ZIP_NAME" {
  default = "tmp/function.zip"
}
variable "AUTOMATED_MESSAGE" {
  default = "AUTOMATED MESSAGE ===> Aloha, thanks for opening a trade request with us. We will be in touch with you shortly. For faster support you can reach out to us at: +1 (808) 351 3486. Mahalo!"
}
provider "aws" {
  access_key = "${var.ACCESS_KEY}"
  secret_key = "${var.SECRET_KEY}"
  region     = "${var.REGION}"
}

# Zip up Lambda function
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "function"
    output_path = "${var.LAMBDA_ZIP_NAME}"
}

# Role for Lambda function
resource "aws_iam_role" "localbtc_notification_handler_lambda_role" {
  name               = "${var.APP_NAME}-lambda-role"
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
    name   = "${var.APP_NAME}-lambda-role-policy"
    role   = "${aws_iam_role.localbtc_notification_handler_lambda_role.id}"
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
      LBC_HMAC_KEY = "${var.LBC_HMAC_KEY}"
      LBC_HMAC_SECRET = "${var.LBC_HMAC_SECRET}"
      PHONE_NUMBER = "${var.PHONE_NUMBER}"
      AUTOMATED_MESSAGE = "${var.AUTOMATED_MESSAGE}"
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
  statement_id   = "AllowExecutionFromCloudWatch"
  action         = "lambda:InvokeFunction"
  function_name  = "${aws_lambda_function.localbtc_notification_handler_lambda.function_name}"
  principal      = "events.amazonaws.com"
  source_arn     = "${aws_cloudwatch_event_rule.scheduled_event.arn}"
  qualifier      = "${aws_lambda_alias.localbtc_notification_handler_lambda_alias.name}"
}

# Create event rule
resource "aws_cloudwatch_event_rule" "scheduled_event" {
  name        = "${var.APP_NAME}-scheduled-event"
  description = "Recurrent event for calling Lambda Function"
  schedule_expression = "${var.SCHEDULE_EXPRESSION}"
}

# Map event rule to trigger lambda function
resource "aws_cloudwatch_event_target" "lambda_trigger" {
  rule      = "${aws_cloudwatch_event_rule.scheduled_event.name}"
  arn       = "${aws_lambda_alias.localbtc_notification_handler_lambda_alias.arn}"
}
