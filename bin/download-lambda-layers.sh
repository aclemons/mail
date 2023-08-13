#!/usr/bin/env bash

set -e

CWD="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

if ! command -v aws > /dev/null 2>&1 ; then
  >&2 printf "aws cli is required.\n"
  exit 2
fi

ARCH="${ARCH:-$(uname -m)}"

LAMBDA_INSIGHTS_VERSION_AMD64=38
LAMBDA_INSIGHTS_VERSION_ARM64=5

PARAMETERS_AND_SECRETS_VERSION_AMD64=4
PARAMETERS_AND_SECRETS_VERSION_ARM64=4

fetch_layer() {
  local arn="$1"
  local output="$2"

  local url
  url="$(aws lambda get-layer-version-by-arn --arn "$arn" --query 'Content.Location' --output text)"
  curl -f -s -o "$output" "$url"
}

if [ "$ARCH" = "aarch64" ] ; then
  find "$CWD/../docker/shared/layers" -type f -name "lambda-insights-arm64-*.zip" -exec rm -rf "{}" \;
  find "$CWD/../docker/shared/layers" -type f -name "parameters-and-secrets-arm64-*.zip" -exec rm -rf "{}" \;

  fetch_layer "arn:aws:lambda:eu-central-1:580247275435:layer:LambdaInsightsExtension-Arm64:$LAMBDA_INSIGHTS_VERSION_ARM64" "$CWD/../docker/shared/layers/lambda-insights-arm64-$LAMBDA_INSIGHTS_VERSION_ARM64.zip"
  fetch_layer "arn:aws:lambda:eu-central-1:187925254637:layer:AWS-Parameters-and-Secrets-Lambda-Extension-Arm64:$PARAMETERS_AND_SECRETS_VERSION_ARM64" "$CWD/../docker/shared/layers/parameters-and-secrets-arm64-$PARAMETERS_AND_SECRETS_VERSION_ARM64.zip"
elif [ "$ARCH" = "x86_64" ] ; then
  find "$CWD/../docker/shared/layers" -type f -name "lambda-insights-amd64-*.zip" -exec rm -rf "{}" \;
  find "$CWD/../docker/shared/layers" -type f -name "parameters-and-secrets-amd64-*.zip" -exec rm -rf "{}" \;

  fetch_layer "arn:aws:lambda:eu-central-1:580247275435:layer:LambdaInsightsExtension:$LAMBDA_INSIGHTS_VERSION_AMD64" "$CWD/../docker/shared/layers/lambda-insights-amd64-$LAMBDA_INSIGHTS_VERSION_AMD64.zip"
  fetch_layer "arn:aws:lambda:eu-central-1:187925254637:layer:AWS-Parameters-and-Secrets-Lambda-Extension:$PARAMETERS_AND_SECRETS_VERSION_AMD64" "$CWD/../docker/shared/layers/parameters-and-secrets-amd64-$PARAMETERS_AND_SECRETS_VERSION_AMD64.zip"
else
  >&2 printf "Unknown arch %s\n" "$ARCH"
  exit 3
fi
