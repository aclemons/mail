#!/usr/bin/env bash

set -e
set -o pipefail

ACCOUNTS="${ACCOUNTS:-}"

if [ -z "$ACCOUNTS" ] ; then
  1>&2 echo "No accounts set?"
  exit 1
fi

MAIN_IMAP="$(printf '%s\n' "$ACCOUNTS" | jq -r '.[0] | .imap')"
export MAIN_IMAP

MAIN_USER="$(printf '%s\n' "$ACCOUNTS" | jq -r '.[0] | .user')"
export MAIN_USER

printf 'Using main imap server %s, logging in with user: %s\n' "$MAIN_IMAP" "$MAIN_USER"

MAIN_PASS="$(printf '%s\n' "$ACCOUNTS" | jq -r '.[0] | .password')"
export MAIN_PASS

ret=0
printf '%s\n' "$ACCOUNTS" | jq -r 'del(.[0])' | jq -c '.[]' | while read -r acc ; do
  OTHER_IMAP="$(printf '%s\n' "$acc" | jq -r '.imap')"
  OTHER_USER="$(printf '%s\n' "$acc" | jq -r '.user')"

  printf 'Moving mail from imap server %s, logging in with user: %s\n' "$OTHER_IMAP" "$OTHER_USER"

  OTHER_REFRESH_TOKEN="$(printf '%s\n' "$acc" | jq -r '.refresh_token' | sed 's/^null$//')"

  OTHER_OAUTH2=""
  OTHER_PASS=""
  if [ -n "$OTHER_REFRESH_TOKEN" ] ; then
    OTHER_CLIENT_ID="$(printf '%s\n' "$acc" | jq -r '.client_id')"
    OTHER_CLIENT_SECRET="$(printf '%s\n' "$acc" | jq -r '.client_secret')"

    OTHER_ACCESS_TOKEN="$(oauth2.py --quiet --user="$OTHER_USER" --client_id="$OTHER_CLIENT_ID" --client_secret="$OTHER_CLIENT_SECRET" --refresh_token="$OTHER_REFRESH_TOKEN")"

    OTHER_OAUTH2="$(oauth2.py --generate_oauth2_string --user="$OTHER_USER" --access_token="$OTHER_ACCESS_TOKEN" | sed -n '$p')"
  else
    OTHER_PASS="$(printf '%s\n' "$acc" | jq -r '.password')"
  fi

  set +e
  OTHER_IMAP="$OTHER_IMAP" \
  OTHER_USER="$OTHER_USER" \
  OTHER_PASS="$OTHER_PASS" \
  OTHER_OAUTH2="$OTHER_OAUTH2" \
  OTHER_JUNK="$(printf '%s\n' "$acc" | jq -r '.junk' | sed 's/^null$//')" \
  HOME="/tmp" \
    imapfilter -v -c /imapfilter/config.lua
  acc_ret=$?
  set -e

  if [ $acc_ret -ne 0 ] ; then
    printf 'Processing mail for %s failed\n' "$OTHER_IMAP"
    ret=$acc_ret
  fi
done

exit $ret
