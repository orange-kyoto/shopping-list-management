package database

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

var (
	dynamoDBClient *dynamodb.Client
)

func init() {
	cfg, err := config.LoadDefaultConfig(context.Background())

	if err != nil {
		panic("Failed init database. Unable to load SDK config, " + err.Error())
	}

	dynamoDBClient = dynamodb.NewFromConfig(cfg)
}

func GetDynamoDBClient() *dynamodb.Client {
	return dynamoDBClient
}
