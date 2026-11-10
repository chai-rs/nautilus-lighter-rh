#!/usr/bin/env bash
# Self-check for lighter-rh.sh: dummy values, no network. Prints "ok".
set -euo pipefail
sh=$(cd "$(dirname "$0")" && pwd)/lighter-rh.sh
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
export LIGHTER_RH_DIR=$d

has()   { case "$1" in *"$2"*) ;; *) echo "FAIL: missing $2"; exit 1 ;; esac; }
hasnt() { case "$1" in *"$2"*) echo "FAIL: unexpected $2"; exit 1 ;; esac; }
fails() { if "$@" >/dev/null 2>&1; then echo "FAIL: expected failure: $*"; exit 1; fi; }

main_env='LIGHTER_ROBINHOOD_API_KEY_INDEX=1
LIGHTER_ROBINHOOD_API_SECRET=dummy-main
LIGHTER_ROBINHOOD_ACCOUNT_INDEX=11
LIGHTER_ROBINHOOD_TESTNET_API_SECRET=stray-test'
test_env='LIGHTER_ROBINHOOD_TESTNET_API_KEY_INDEX=2
LIGHTER_ROBINHOOD_TESTNET_API_SECRET=dummy-test
LIGHTER_ROBINHOOD_TESTNET_ACCOUNT_INDEX=22'
echo "$main_env" > "$d/mainnet.env"; echo "$test_env" > "$d/testnet.env"; chmod 600 "$d"/*.env

# Keys that leak from the parent shell must not reach a session.
export LIGHTER_ROBINHOOD_API_SECRET=leak-main LIGHTER_ROBINHOOD_TESTNET_API_SECRET=leak-test

out=$(bash "$sh" mainnet env 2>"$d/err")
has "$out" "LIGHTER_DEPLOYMENT=robinhood"; has "$out" "LIGHTER_ENVIRONMENT=mainnet"
has "$out" "LIGHTER_RH_HTTP_URL=https://api.rh.lighter.xyz"
has "$out" "LIGHTER_RH_WS_URL=wss://api.rh.lighter.xyz/stream"
has "$out" "LIGHTER_ROBINHOOD_API_SECRET=dummy-main"
hasnt "$out" "LIGHTER_ROBINHOOD_TESTNET_"; hasnt "$out" "leak-"
err=$(cat "$d/err"); has "$err" "credentials loaded"; hasnt "$err" "dummy"

out=$(bash "$sh" testnet env 2>/dev/null)
has "$out" "LIGHTER_ENVIRONMENT=testnet"
has "$out" "LIGHTER_RH_HTTP_URL=https://api.rh-testnet.lighter.xyz"
has "$out" "LIGHTER_RH_WS_URL=wss://api.rh-testnet.lighter.xyz/stream"
has "$out" "LIGHTER_ROBINHOOD_TESTNET_API_SECRET=dummy-test"
hasnt "$out" "LIGHTER_ROBINHOOD_API_"; hasnt "$out" "leak-"

fails bash "$sh" devnet env
fails bash "$sh"
chmod 644 "$d/mainnet.env"; fails bash "$sh" mainnet env; chmod 600 "$d/mainnet.env"
echo "$main_env" > "$d/testnet.env"; fails bash "$sh" testnet env   # wrong prefix

rm "$d"/*.env
out=$(bash "$sh" mainnet env 2>"$d/err")
has "$out" "LIGHTER_ENVIRONMENT=mainnet"; hasnt "$out" "_API_SECRET"
has "$(cat "$d/err")" "no credentials"
echo ok
