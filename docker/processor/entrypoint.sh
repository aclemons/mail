#!/usr/bin/env bash

set -e
set -o pipefail

printf 'Starting lambda handler. Running as pid %s, user %s\n' "$BASHPID" "$(id -u)"

PARAMETERS_SECRETS_EXTENSION_HTTP_PORT=${PARAMETERS_SECRETS_EXTENSION_HTTP_PORT:-2773}

imap_host_url="http://localhost:$PARAMETERS_SECRETS_EXTENSION_HTTP_PORT/systemsmanager/parameters/get/?name=/mail/processor/imap_host&withDecryption=true"
imap_user_url="http://localhost:$PARAMETERS_SECRETS_EXTENSION_HTTP_PORT/systemsmanager/parameters/get/?name=/mail/processor/imap_user&withDecryption=true"
imap_pass_url="http://localhost:$PARAMETERS_SECRETS_EXTENSION_HTTP_PORT/systemsmanager/parameters/get/?name=/mail/processor/imap_pass&withDecryption=true"

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
  printf 'Processing payload %s\n' "$(cat "$BODY")"

  printf 'Fetching imap host from parameters and secrets extension %s\n' "$imap_host_url"
  IMAP_HOST="$(curl -f -s -H "X-Aws-Parameters-Secrets-Token: $AWS_SESSION_TOKEN" "$imap_host_url" | jq -r '.Parameter | .Value')"
  printf 'Fetching imap user from parameters and secrets extension %s\n' "$imap_user_url"
  IMAP_USER="$(curl -f -s -H "X-Aws-Parameters-Secrets-Token: $AWS_SESSION_TOKEN" "$imap_user_url" | jq -r '.Parameter | .Value')"
  printf 'Fetching imap pass from parameters and secrets extension %s\n' "$imap_pass_url"
  IMAP_PASS="$(curl -f -s -H "X-Aws-Parameters-Secrets-Token: $AWS_SESSION_TOKEN" "$imap_pass_url" | jq -r '.Parameter | .Value')"

  printf 'Connection to %s as %s:*****\n' "$IMAP_HOST" "$IMAP_USER"

  ret=0
  IMAP_USER="$IMAP_USER" IMAP_PASS="$IMAP_PASS" IMAP_HOST="$IMAP_HOST" /usr/local/bin/processor || ret=$?

  if [ $ret -eq 0 ] ; then
    curl -f -sS -X POST "http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/$REQUEST_ID/response" -d "{\"result\": 0}"
  else
    printf 'processor failed\n'
    curl -f -sS -X POST "http://$AWS_LAMBDA_RUNTIME_API/2018-06-01/runtime/invocation/$REQUEST_ID/response" -d "{\"result\": $ret}"
  fi
  rm -rf "$BODY"
done
