#!/usr/bin/env bash

set -e
set -o pipefail

printf 'Starting lambda handler. Running as pid %s, user %s\n' "$BASHPID" "$(id -u)"

PARAMETERS_SECRETS_EXTENSION_HTTP_PORT=${PARAMETERS_SECRETS_EXTENSION_HTTP_PORT:-2773}

url="http://localhost:$PARAMETERS_SECRETS_EXTENSION_HTTP_PORT/systemsmanager/parameters/get/?name=/mail/imapfilter/accounts&withDecryption=true"

shutdown() {
  printf 'Shutting down gracefully\n'
  exit
}
trap 'shutdown' SIGTERM

while true ; do
  HEADERS="$(mktemp)"
  BODY="$(mktemp)"
  curl -f -sS -LD "$HEADERS" -X GET "http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/next" -o "$BODY"
  REQUEST_ID="$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)"
  rm -rf "$HEADERS"

  printf 'Processing request %s\n' "$REQUEST_ID"

  printf 'Fetching accounts from parameters and secrets extension %s\n' "$url"
  ACCOUNTS="$(curl -f -s -H "X-Aws-Parameters-Secrets-Token: $AWS_SESSION_TOKEN" "$url" | jq '.Parameter | .Value | fromjson')"

  ret=0
  ACCOUNTS="$ACCOUNTS" /imapfilter/run.sh || ret=$?

  if [ $ret -eq 0 ] ; then
    curl -f -sS -X POST "http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/$REQUEST_ID/response" -d "{\"result\": 0}"
  else
    printf 'run.sh failed\n'
    curl -f -sS -X POST "http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/$REQUEST_ID/response" -d "{\"result\": $ret}"
  fi
  rm -rf "$BODY"
done
