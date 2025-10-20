variable "region" {
  type    = string
  default = "us-east-1"
}

variable "function_zip" {
  type = string
  # Example: "../lambda/function.zip" (you will create this file)
}

variable "function_name" {
  type    = string
  default = "go-crud-lambda"
}

variable "dynamo_table" {
  type    = string
  default = "go-crud-table"
}
