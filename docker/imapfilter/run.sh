#!/usr/bin/env bash

set -e
set -o pipefail

ACCOUNTS="${ACCOUNTS:-}"

if [ -z "$ACCOUNTS" ] ; then
  echo "No accounts set?"
  exit 1
fi

MAIN_IMAP="$(printf '%s\n' "$ACCOUNTS" | jq -r '.[0] | .imap')"
export MAIN_IMAP

MAIN_USER="$(printf '%s\n' "$ACCOUNTS" | jq -r '.[0] | .user')"
export MAIN_USER

printf 'Using main imap server %s, logging in with user: %s\n' "$MAIN_IMAP" "$MAIN_USER"

MAIN_PASS="$(printf '%s\n' "$ACCOUNTS" | jq -r '.[0] | .password')"
export MAIN_PASS

printf '%s\n' "$ACCOUNTS" | jq -r 'del(.[0])' | jq -c '.[]' | while read -r acc ; do
  OTHER_IMAP="$(printf '%s\n' "$acc" | jq -r '.imap')" \
  OTHER_USER="$(printf '%s\n' "$acc" | jq -r '.user')" \
  OTHER_PASS="$(printf '%s\n' "$acc" | jq -r '.password')" \
  OTHER_JUNK="$(printf '%s\n' "$acc" | jq -r '.junk' | sed 's/^null$//')" \
    imapfilter -v -c /imapfilter/config.lua
done
