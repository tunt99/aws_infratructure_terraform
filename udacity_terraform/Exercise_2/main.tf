terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  profile = "TuNT"
  region = var.aws_region
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "greet_lambda.py"
  output_path = "output_lambda.zip"
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "lambda_role" {
  name = "my-lambda-role"

  assume_role_policy = <<EOF
    {   
    "Version": "2012-10-17",
    "Statement": [
        {
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
resource "aws_lambda_function" "my_lambda" {
  function_name = "my-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "greet_lambda.lambda_handler"
  runtime       = "python3.8"
  filename      = "output_lambda.zip"
  source_code_hash = filebase64sha256("output_lambda.zip")

  environment{
      variables = {
          greeting = "Hello World!"
      }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_policy, aws_cloudwatch_log_group.lambda_log_group]
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/my-lambda-function"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_resource_policy" "lambda_log_policy" {
  policy_name = "lambda-log-policy"
  policy_document = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
      {
      "Sid": "AllowLambdaLogs",
      "Effect": "Allow",
      "Principal": {
          "Service": "lambda.amazonaws.com"
      },
      "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutMetricFilter",
          "logs:PutRetentionPolicy"
      ],
      "Resource": "arn:aws:logs:*:*:*"
      }
    ]
  }
  EOF
}

resource "aws_lambda_permission" "lambda_cloudwatch_permission" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal = "logs.amazonaws.com"
  source_arn = aws_cloudwatch_log_group.lambda_log_group.arn
}