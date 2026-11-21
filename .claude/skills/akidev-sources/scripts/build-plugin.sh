#!/usr/bin/env bash
#
# Builds a code plugin's module, puts its hash in the plugin, and checks the result.
#
#   scripts/build-plugin.sh <module crate folder> <plugin.json> <output folder>
#
# For example, from a copy of templates/guest-indexer and templates/plugin-code-indexer.json:
#   scripts/build-plugin.sh ./my-site ./my-site.json ./out
#
# It writes <output>/<module.file> and <output>/<plugin id>.json (with the real module.sha256), then runs
# check-source.sh on them. Needs the wasm32 target (rustup target add wasm32-unknown-unknown). If your default
# toolchain lacks it, name one that has it: TOOLCHAIN=1.95.0-aarch64-apple-darwin scripts/build-plugin.sh ...

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[ $# -eq 3 ] || { echo "usage: build-plugin.sh <crate folder> <plugin.json> <output folder>" >&2; exit 2; }
crate="$(cd "$1" && pwd)"
plugin="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
mkdir -p "$3"
out="$(cd "$3" && pwd)"

name="$(sed -n 's/^name *= *"\(.*\)"/\1/p' "$crate/Cargo.toml" | head -1)"
file="$(jq -r '.module.file' "$plugin")"
id="$(jq -r '.id' "$plugin")"
[ -n "$name" ] && [ "$file" != "null" ] && [ "$id" != "null" ] || { echo "The crate needs a name, and the plugin a module.file and an id." >&2; exit 2; }

echo "Building $name ..."
(cd "$crate" && cargo ${TOOLCHAIN:+"+$TOOLCHAIN"} build --release --target wasm32-unknown-unknown) || {
  echo "The build failed. If it says the wasm32 target is missing, run: rustup target add wasm32-unknown-unknown" >&2
  exit 1
}
built="$crate/target/wasm32-unknown-unknown/release/$(echo "$name" | tr '-' '_').wasm"
[ -f "$built" ] || { echo "Expected $built" >&2; exit 1; }

cp "$built" "$out/$file"
hash="$(shasum -a 256 "$out/$file" | cut -d' ' -f1)"
jq --arg hash "$hash" '.module.sha256 = $hash' "$plugin" > "$out/$id.json"
echo "Module: $out/$file ($(wc -c < "$out/$file") bytes, sha256 $hash)"
echo "Plugin: $out/$id.json"
"$here/check-source.sh" "$out/$id.json" "$out/$file"
