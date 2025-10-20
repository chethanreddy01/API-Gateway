package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
)

type Item struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

var (
	tableName = os.Getenv("DYNAMO_TABLE")
	svc       *dynamodb.DynamoDB
)

func init() {
	sess := session.Must(session.NewSession())
	svc = dynamodb.New(sess)
}

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	switch req.HTTPMethod {
	case "POST":
		return handlePost(req)
	case "GET":
		id := req.PathParameters["id"]
		if id == "" {
			return handleGetAll()
		}
		return handleGet(id)
	case "PUT":
		return handlePut(req)
	case "DELETE":
		id := req.PathParameters["id"]
		return handleDelete(id)
	default:
		return events.APIGatewayProxyResponse{StatusCode: 405}, nil
	}
}

// POST /items
func handlePost(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var item Item
	err := json.Unmarshal([]byte(req.Body), &item)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 400, Body: err.Error()}, nil
	}

	_, err = svc.PutItem(&dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item: map[string]*dynamodb.AttributeValue{
			"id":   {S: aws.String(item.ID)},
			"name": {S: aws.String(item.Name)},
		},
	})
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: err.Error()}, nil
	}

	body, _ := json.Marshal(item)
	return events.APIGatewayProxyResponse{StatusCode: 200, Body: string(body)}, nil
}

// GET /items
func handleGetAll() (events.APIGatewayProxyResponse, error) {
	resp, err := svc.Scan(&dynamodb.ScanInput{TableName: aws.String(tableName)})
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: err.Error()}, nil
	}

	items := []Item{}
	for _, i := range resp.Items {
		items = append(items, Item{
			ID:   *i["id"].S,
			Name: *i["name"].S,
		})
	}

	body, _ := json.Marshal(items)
	return events.APIGatewayProxyResponse{StatusCode: 200, Body: string(body)}, nil
}

// GET /items/{id}
func handleGet(id string) (events.APIGatewayProxyResponse, error) {
	resp, err := svc.GetItem(&dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]*dynamodb.AttributeValue{
			"id": {S: aws.String(id)},
		},
	})
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: err.Error()}, nil
	}

	if resp.Item == nil {
		return events.APIGatewayProxyResponse{StatusCode: 404, Body: "Item not found"}, nil
	}

	item := Item{
		ID:   *resp.Item["id"].S,
		Name: *resp.Item["name"].S,
	}

	body, _ := json.Marshal(item)
	return events.APIGatewayProxyResponse{StatusCode: 200, Body: string(body)}, nil
}

// PUT /items/{id}
func handlePut(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	id := req.PathParameters["id"]
	var item Item
	err := json.Unmarshal([]byte(req.Body), &item)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 400, Body: err.Error()}, nil
	}
	item.ID = id

	_, err = svc.PutItem(&dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item: map[string]*dynamodb.AttributeValue{
			"id":   {S: aws.String(item.ID)},
			"name": {S: aws.String(item.Name)},
		},
	})
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: err.Error()}, nil
	}

	body, _ := json.Marshal(item)
	return events.APIGatewayProxyResponse{StatusCode: 200, Body: string(body)}, nil
}

// DELETE /items/{id}
func handleDelete(id string) (events.APIGatewayProxyResponse, error) {
	_, err := svc.DeleteItem(&dynamodb.DeleteItemInput{
		TableName: aws.String(tableName),
		Key: map[string]*dynamodb.AttributeValue{
			"id": {S: aws.String(id)},
		},
	})
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: err.Error()}, nil
	}

	return events.APIGatewayProxyResponse{StatusCode: 200, Body: fmt.Sprintf("Deleted item %s", id)}, nil
}

func main() {
	lambda.Start(handler)
}
