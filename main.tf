provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "App"       = "shopping-list-management"
      "Env"       = "dev" // TODO: fix
      "ManagedBy" = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Action" : "sts:AssumeRole",
      "Principal" : {
        "Service" : "lambda.amazonaws.com"
      },
      "Effect" : "Allow",
      "Sid" : ""
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      # DynamoDBへのアクセス許可
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          # "dynamodb:Scan",
          "dynamodb:Query"
        ],
        "Resource" : [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
        ]
      },
      # CloudWatch Logsへのアクセス許可
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      # API Gateway Management APIへのアクセス許可（WebSocketの場合）
      {
        "Effect" : "Allow",
        "Action" : [
          "execute-api:ManageConnections"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# IAMロールとポリシーの関連付け
resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda関数の作成
resource "aws_lambda_function" "handle_connect_route" {
  function_name    = "handle-connect-route-dev"
  role             = aws_iam_role.lambda_role.arn
  architectures    = ["arm64"]
  handler          = "main"
  filename         = "handle-connect-route-dev.zip"
  source_code_hash = filebase64sha256("handle-connect-route-dev.zip")
  runtime          = "go1.x"
  timeout          = 30

  environment {
    variables = {
      // TODO: tfファイルで作成したリソースを参照する
      DYNAMODB_TABLE_NAME  = "shopping-list-management-users-dev"
      API_GATEWAY_ENDPOINT = ""
    }
  }
}

# API Gateway WebSocket APIの作成
resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "shopping-list-management-websocket-api-dev"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

# $defaultルートの設定
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$default"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Lambda統合の設定
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.handle_connect_route.invoke_arn
}

# デプロイの設定
resource "aws_apigatewayv2_deployment" "websocket_deployment" {
  api_id = aws_apigatewayv2_api.websocket_api.id

  # リソース間の依存関係を明示
  depends_on = [
    aws_apigatewayv2_integration.lambda_integration,
    aws_apigatewayv2_route.default_route
  ]
}

# ステージの設定
resource "aws_apigatewayv2_stage" "websocket_stage" {
  api_id        = aws_apigatewayv2_api.websocket_api.id
  name          = "dev"
  deployment_id = aws_apigatewayv2_deployment.websocket_deployment.id
}

# LambdaにAPI Gatewayからの実行を許可
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handle_connect_route.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.websocket_api.execution_arn}/*"
}

resource "aws_dynamodb_table" "users_table" {
  name         = "shopping-list-management-users-dev"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "user_email"
    type = "S"
  }

  attribute {
    name = "connection_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  attribute {
    name = "updated_at"
    type = "S"
  }
}
