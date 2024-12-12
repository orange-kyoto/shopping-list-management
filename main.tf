provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "App"       = "shopping-list-management"
      "Env"       = local.env
      "Terraform" = "true"
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  env                       = "dev" // TODO: fix
  dynamodb_users_table_name = "shopping-list-management-users-${local.env}"
}

/*
  １つ１つやっていく。
  必要なインフラリソースは以下の通り。
  - API Gateway (WebSocket API)
  - API Gateway (REST API)
  - Lambda Function
    - handle-connect-route
    - create-user (initialize-user くらいで良いかもね。ショッピングリストの初期化もあるし。)
  - DynamoDB Table
    - users
    - shopping-lists
  - VPC (LambdaからDynamoDBにPrivateにアクセスするため)

  できるだけ terraform module を使って簡潔に実装する。
*/

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "shopping-list-management-vpc-${local.env}"
  cidr = "10.0.0.0/16"

  azs           = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  intra_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

module "security_group_lambda" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "shopping-list-management-sg-lambda-${local.env}"
  description = "Security Group for Lambda Egress"

  vpc_id = module.vpc.vpc_id

  egress_cidr_blocks      = []
  egress_ipv6_cidr_blocks = []

  # Prefix list ids to use in all egress rules in this module
  egress_prefix_list_ids = [module.vpc_endpoints.endpoints["dynamodb"]["prefix_list_id"]]

  egress_rules = ["https-443-tcp"]
}

// TODO: Lambda 関数の設定はほぼ同じなので、for_each を使って簡潔に書く
module "handle_connect_route_lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.17.0"

  function_name = "shopping-list-management-handle-connect-route-${local.env}"
  handler       = "main"
  runtime       = "provided.al2023"
  timeout       = 30
  architectures = ["arm64"]

  create_package         = false
  local_existing_package = "./build/lambda/handle-connect-route-${local.env}.zip"

  vpc_subnet_ids         = module.vpc.intra_subnets
  vpc_security_group_ids = [module.security_group_lambda.security_group_id]
  attach_network_policy  = true

  attach_policy_statements = true
  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "dynamodb:Query",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ]
      resources = [
        "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_users_table_name}"
      ]
    }
  ]

  allowed_triggers = {
    // TODO: API Gateway の WebSocket API から呼び出せることを設定する
  }

  cloudwatch_logs_retention_in_days = 1

  environment_variables = {
    DYNAMODB_USER_TABLE_NAME = "shopping-list-management-users-${local.env}"
  }
}

// TODO: Lambda 関数の設定はほぼ同じなので、for_each を使って簡潔に書く
module "create_user_lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.17.0"

  function_name = "shopping-list-management-create-user-${local.env}"
  handler       = "handler"
  runtime       = "provided.al2023"
  timeout       = 30
  architectures = ["arm64"]

  create_package         = false
  local_existing_package = "./build/lambda/create-user-${local.env}.zip"

  vpc_subnet_ids         = module.vpc.intra_subnets
  vpc_security_group_ids = [module.security_group_lambda.security_group_id]
  attach_network_policy  = true

  attach_policy_statements = true
  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "dynamodb:Query",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ]
      resources = [
        "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_users_table_name}"
      ]
    }
  ]

  allowed_triggers = {
    // TODO: API Gateway の WebSocket API から呼び出せることを設定する
  }

  cloudwatch_logs_retention_in_days = 1

  environment_variables = {
    DYNAMODB_USER_TABLE_NAME = "shopping-list-management-users-${local.env}"
  }
}

resource "aws_dynamodb_table" "users_table" {
  name         = local.dynamodb_users_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  tags = {
    Name = "users_table_${local.env}"
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.16.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.security_group_lambda.security_group_id]

  endpoints = {
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = module.vpc.intra_route_table_ids
      tags = {
        Name = "shopping-list-management-dynamodb-endpoint-${local.env}"
      }
    },
  }
}
