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

if [ "$ARCH" = "aarch64" ] ; then
  find "$CWD/../docker/shared/layers" -type f -name "lambda-insights-arm64-*.zip" -exec rm -rf "{}" \;
  url="$(aws lambda get-layer-version-by-arn --arn "arn:aws:lambda:eu-central-1:580247275435:layer:LambdaInsightsExtension-Arm64:$LAMBDA_INSIGHTS_VERSION_ARM64" --query 'Content.Location' --output text)"
  curl -f -s -o "$CWD/../docker/shared/layers/lambda-insights-arm64-$LAMBDA_INSIGHTS_VERSION_ARM64.zip" "$url"
elif [ "$ARCH" = "x86_64" ] ; then
  find "$CWD/../docker/shared/layers" -type f -name "lambda-insights-amd64-*.zip" -exec rm -rf "{}" \;
  url="$(aws lambda get-layer-version-by-arn --arn "arn:aws:lambda:eu-central-1:580247275435:layer:LambdaInsightsExtension:$LAMBDA_INSIGHTS_VERSION_AMD64" --query 'Content.Location' --output text)"
  curl -f -s -o "$CWD/../docker/shared/layers/lambda-insights-amd64-$LAMBDA_INSIGHTS_VERSION_AMD64.zip" "$url"
else
  >&2 printf "Unknown arch %s\n" "$ARCH"
  exit 3
fi
