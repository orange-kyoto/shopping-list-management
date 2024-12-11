package database

import (
	"context"
	"os"

	databaseTypes "shoppint-list-management/database/types"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

var tableName = os.Getenv("DYNAMODB_USER_TABLE_NAME")

func GetUserItem(ctx context.Context, userId string) (*databaseTypes.UserItem, error) {
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

	user := databaseTypes.UserItem{}
	err = attributevalue.UnmarshalMap(result.Item, &user)
	if err != nil {
		return nil, err
	}

	return &user, nil
}

func CreateUserItem(ctx context.Context, userItem databaseTypes.UserItem) error {
	input, err := attributevalue.MarshalMap(userItem)

	if err != nil {
		return err
	}

	_, err = dynamoDBClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      input,
	})

	return err
}
