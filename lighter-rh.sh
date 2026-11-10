#!/usr/bin/env bash
# lighter-rh: open a shell (or run one command) set up for Lighter on Robinhood Chain.
#
#   lighter-rh.sh mainnet              # new shell, mainnet session; `exit` to leave
#   lighter-rh.sh testnet cargo run …  # one command in a testnet session
#
# Credentials are optional (public data needs none). They come only from
#   ${LIGHTER_RH_DIR:-~/.config/lighter-rh}/<mainnet|testnet>.env   (chmod 600)
# This script never prints a credential value.
set -euo pipefail

usage() { echo "usage: ${0##*/} <mainnet|testnet> [command...]" >&2; exit 2; }
[ $# -ge 1 ] || usage
net=$1; shift

case $net in
  mainnet) prefix=LIGHTER_ROBINHOOD         other=LIGHTER_ROBINHOOD_TESTNET host=api.rh.lighter.xyz ;;
  testnet) prefix=LIGHTER_ROBINHOOD_TESTNET other=LIGHTER_ROBINHOOD         host=api.rh-testnet.lighter.xyz ;;
  *) usage ;;
esac

drop() { unset "${1}_API_KEY_INDEX" "${1}_API_SECRET" "${1}_ACCOUNT_INDEX"; }

# The session takes credentials from the file only, never from the parent shell.
drop "$prefix"; drop "$other"

creds=${LIGHTER_RH_DIR:-$HOME/.config/lighter-rh}/$net.env
if [ -f "$creds" ]; then
  case $(ls -lL "$creds") in
    -rw-------*|-r--------*) ;;
    *) echo "refused: $creds must have mode 600; run: chmod 600 $creds" >&2; exit 1 ;;
  esac
  set -a; . "$creds"; set +a
  for v in API_KEY_INDEX API_SECRET ACCOUNT_INDEX; do
    n=${prefix}_$v
    [ -n "${!n:-}" ] || { echo "refused: $creds does not set $n" >&2; exit 1; }
  done
  drop "$other"   # a file must not bring the key of the other network
  state="credentials loaded"
else
  state="no credentials, public data only"
fi

# lighter-flatten reads these two; your own node can read them too (see README).
export LIGHTER_DEPLOYMENT=robinhood LIGHTER_ENVIRONMENT=$net
export LIGHTER_RH_SESSION=$net
export LIGHTER_RH_HTTP_URL=https://$host LIGHTER_RH_WS_URL=wss://$host/stream

echo "lighter-rh: $net session, $LIGHTER_RH_HTTP_URL, $state" >&2
[ $# -gt 0 ] || set -- "${SHELL:-/bin/sh}"
exec "$@"
