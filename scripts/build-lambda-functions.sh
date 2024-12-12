#!/bin/bash

set -e

cd "$(dirname $0)"/..

export GOOS=linux
export GOARCH=arm64

environment=dev

funcion_names=(
    handle-connect-route
    create-user
)

for function_name in "${funcion_names[@]}"; do
    go build -o ./build/lambda/${function_name}-${environment}/bootstrap ./aws-lambda/${function_name}/main.go && \
        zip -j ./build/lambda/${function_name}-${environment}.zip ./build/lambda/${function_name}-${environment}/bootstrap
done

exit 0
