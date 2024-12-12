package main

/*
	Googleでのサインアップに成功した際にユーザーをDynamoDBに作成するLambda関数
*/

import (
	"context"
	"encoding/json"
	"fmt"
	"shoppint-list-management/database"
	databaseTypes "shoppint-list-management/database/types"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

var (
	dynamoDBClient *dynamodb.Client
)

func init() {
	dynamoDBClient = database.GetDynamoDBClient()
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	fmt.Println("Received request:", request)

	var userItem databaseTypes.UserItem
	err := json.Unmarshal([]byte(request.Body), &userItem)
	if err != nil {
		fmt.Println("Error parsing request body:", err)
		return events.APIGatewayProxyResponse{
			StatusCode: 400,
			Body:       "Bad Request",
		}, nil
	}

	// TODO: 入力バリデーション。もしかしたら、重複チェックをしてもいいかもだけど、その場合は単にスルーしてもいい。
	// API spec から自動で型やロジックを導出したい。

	err = database.CreateUserItem(ctx, userItem)
	if err != nil {
		fmt.Println("Error creating user item: ", err)
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       "Internal Server Error",
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       "User created",
	}, nil
}

func main() {
	lambda.Start(handler)
}
