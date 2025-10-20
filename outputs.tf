output "lambda_function_name" {
  value = aws_lambda_function.go_lambda.function_name
}

output "dynamo_table_name" {
  value = aws_dynamodb_table.items.name
}

output "api_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}
