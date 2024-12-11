package main

/*
	TODO: 一通りのざっくりした機能を実装したらバグ修正やテスト実装しながらリファクタリングする。
*/

import (
	"context"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

var (
	dynamoDBClient *dynamodb.Client
	tableName      = os.Getenv("DYNAMODB_USER_TABLE_NAME")
)

type User struct {
	// TODO: 適切なデータ構造を設計する
	// shoppint_list_id とかは少なくとも必要と思われる
	UserID       string `json:"user_id"`
	UserEmail    string `json:"user_email"`
	ConnectionID string `json:"connection_id"`
}

func init() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic("Unable to load SDK config, " + err.Error())
	}

	dynamoDBClient = dynamodb.NewFromConfig(cfg)
}

func handler(ctx context.Context, request events.APIGatewayWebsocketProxyRequest) (events.APIGatewayProxyResponse, error) {
	fmt.Println("Received connect event:", request)

	connectionID := request.RequestContext.ConnectionID

	// TODO: ユーザーIDをどこから取得するか検討する。
	// connect route では Lambda Authorizer を使って認証を通す予定。
	userId := request.QueryStringParameters["userID"]
	if userId == "" {
		return events.APIGatewayProxyResponse{
			StatusCode: 400,
			Body:       "Missing userID",
		}, nil
	}

	user, err := getUser(ctx, userId)
	if user == nil {
		// NOTE: ユーザーの新規作成 or ログイン処理が成功した前提で websocket の接続をする。
		return events.APIGatewayProxyResponse{
			StatusCode: 404,
			Body:       "User not found",
		}, nil
	}

	user.ConnectionID = connectionID
	err = updateUserConnectionID(ctx, user)
	if err != nil {
		fmt.Println("Error updating user connection ID: ", err)
		return events.APIGatewayProxyResponse{
			StatusCode: 500,
			Body:       "Failed to update user connection ID",
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       "Connected!",
	}, nil
}

func getUser(ctx context.Context, userId string) (*User, error) {
	input := &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"userId": &types.AttributeValueMemberS{Value: userId},
		},
	}

	result, err := dynamoDBClient.GetItem(ctx, input)
	if err != nil {
		return nil, err
	}

	user := User{}
	err = attributevalue.UnmarshalMap(result.Item, &user)
	if err != nil {
		return nil, err
	}

	return &user, nil
}

func updateUserConnectionID(ctx context.Context, user *User) error {
	input := &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"userId": &types.AttributeValueMemberS{Value: user.UserID},
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":connectionId": &types.AttributeValueMemberS{Value: user.ConnectionID},
		},
		UpdateExpression: aws.String("SET connectionId = :connectionId"),
	}

	_, err := dynamoDBClient.UpdateItem(ctx, input)
	return err
}

func main() {
	lambda.Start(handler)
}
