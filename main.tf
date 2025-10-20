# DynamoDB table
resource "aws_dynamodb_table" "items" {
  name           = var.dynamo_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
  tags = {
    Project = "go-crud"
  }
}

# IAM role for Lambda
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.items.arn
      }
    ]
  })
}

# Lambda function (using local zip file you create)
resource "aws_lambda_function" "go_lambda" {
  filename         = var.function_zip      # path to function.zip (local)
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap"     # must match the binary name
  runtime = "provided.al2"
  source_code_hash = filebase64sha256(var.function_zip)

environment {
    variables = {
      DYNAMO_TABLE = aws_dynamodb_table.items.name
    }
  }
}

# API Gateway (REST API) + integration (proxy)
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.function_name}-api"
  description = "API for Go Lambda CRUD"
}

resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "items"
}

resource "aws_api_gateway_resource" "item" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{id}"
}

# Methods
resource "aws_api_gateway_method" "items_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "items_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "item_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "item_put" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "item_delete" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# Lambda integration (proxy)
resource "aws_api_gateway_integration" "lambda_integration_items" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.items_get.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = aws_lambda_function.go_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_integration_items_post" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.items.id
  http_method = aws_api_gateway_method.items_post.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = aws_lambda_function.go_lambda.invoke_arn
}

# integrations for item resource
resource "aws_api_gateway_integration" "lambda_integration_item_get" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.item.id
  http_method = aws_api_gateway_method.item_get.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = aws_lambda_function.go_lambda.invoke_arn
}
resource "aws_api_gateway_integration" "lambda_integration_item_put" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.item.id
  http_method = aws_api_gateway_method.item_put.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = aws_lambda_function.go_lambda.invoke_arn
}
resource "aws_api_gateway_integration" "lambda_integration_item_delete" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.item.id
  http_method = aws_api_gateway_method.item_delete.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = aws_lambda_function.go_lambda.invoke_arn
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.go_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deployment & stage
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration_items,
    aws_api_gateway_integration.lambda_integration_items_post,
    aws_api_gateway_integration.lambda_integration_item_get,
    aws_api_gateway_integration.lambda_integration_item_put,
    aws_api_gateway_integration.lambda_integration_item_delete,
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "dev"
}

output "api_invoke_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}"
}
