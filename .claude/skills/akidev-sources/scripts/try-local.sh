#!/usr/bin/env bash
#
# Tries a sources document against a real local server and shows which sources found releases.
#
#   scripts/try-local.sh path/to/sources.json <title id> [more title ids]
#
# Title ids: series-tt0903747-s1e5 (a series episode), movie-tt0111161 (a film), anime-16498-ep1 (an anime).
# It puts a copy of your document (with a very high version, so the live one cannot replace it) where the
# build reads its built-in copy, starts the server on this machine, asks /v1/releases for each id, prints how
# many releases each source found, then stops the server and puts everything back. Nothing is published and
# nothing leaves this machine except the requests the sources themselves make.
#
# The first run compiles the server with your document, which takes a few minutes.
# Set PORT (default 9187) if that port is busy. Needs the code repo: CODE_REPO, or ../akidev next to this repo.

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
sources_repo="$(cd "$here/../../../.." && pwd)"
code="${CODE_REPO:-$sources_repo/../akidev}"
[ -d "$code/desktop/core" ] || { echo "Set CODE_REPO to a checkout of dishant0406/akidev (not found: $code)" >&2; exit 2; }
[ $# -ge 2 ] || { echo "usage: try-local.sh <sources.json> <title id> [more ids]" >&2; exit 2; }

doc="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; shift
port="${PORT:-9187}"
work="$(mktemp -d)"
cd "$code/desktop"
mkdir -p sources
saved=""
[ -f sources/sources.json ] && { saved="$work/saved-sources.json"; cp sources/sources.json "$saved"; }
server_pid=""

cleanup() {
  [ -n "$server_pid" ] && kill "$server_pid" 2> /dev/null || true
  if [ -n "$saved" ]; then cp "$saved" sources/sources.json; else rm -f sources/sources.json; fi
  rm -rf "$work"
}
trap cleanup EXIT

jq '.version = 1000000000' "$doc" > sources/sources.json
echo "Building the server with your document ..."
cargo build -q -p akidev-server
echo "Starting it on port $port ..."
PORT="$port" CACHE_DIR="$work/cache" STREAM_SOURCES=torrent LISTEN_PORT="$((port + 100))" \
  RUST_LOG=akidev_core=info,akidev_server=info target/debug/akidev-server > "$work/server.log" 2>&1 &
server_pid=$!
for _ in $(seq 1 90); do
  curl -s -m 2 "localhost:$port/health" > /dev/null && break
  kill -0 "$server_pid" 2> /dev/null || { echo "The server stopped:" >&2; tail -20 "$work/server.log" >&2; exit 1; }
  sleep 2
done
curl -s -m 2 "localhost:$port/health" > /dev/null || { echo "The server did not start in time." >&2; exit 1; }

for id in "$@"; do
  echo
  echo "== $id"
  answer="$(curl -s -m 120 "localhost:$port/v1/releases?id=$id")"
  echo "$answer" | jq -e '.releases' > /dev/null 2>&1 || { echo "No releases: $answer" | cut -c1-300; continue; }
  echo "$answer" | jq -r '"\(.releases | length) releases"'
  echo "By source:"
  echo "$answer" | jq -r '.releases | map(.source) | group_by(.) | map("  \(.[0]): \(length)") | .[]'
  echo "Top releases:"
  echo "$answer" | jq -r '.releases[0:5][] | "  [\(.source)] \(.title) (seeders: \(.seeders // "?"))"'
done
echo
echo "Server log lines about indexers that failed (if any):"
grep -E "provider request failed|WARN" "$work/server.log" | sed -E 's/\x1b\[[0-9;]*m//g' | sort | uniq -c | sort -rn | head -10 || true
