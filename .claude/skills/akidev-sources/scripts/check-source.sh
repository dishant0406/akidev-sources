#!/usr/bin/env bash
#
# Checks a sources document or a plugin with the engine's real rules.
#
#   scripts/check-source.sh path/to/sources.json            a whole document
#   scripts/check-source.sh path/to/entry.json              one indexer, provider, subtitle source, mapper
#                                                           or screens entry, put into a copy of this repo's
#                                                           sources.json (an entry with an id that is already
#                                                           there replaces it)
#   scripts/check-source.sh path/to/plugin.json [module.wasm]   a plugin (the module, if given, must match the
#                                                           hash in the plugin)
#
# A file with a "plugin" key is a plugin; one with a "schema" key is a document; anything else is an entry,
# recognised by its keys. Needs the code repo (dishant0406/akidev):
# set CODE_REPO to a checkout, or keep it next to this repo as ../akidev. Exits 0 when the file is accepted.

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
sources_repo="$(cd "$here/../../../.." && pwd)"
code="${CODE_REPO:-$sources_repo/../akidev}"
[ -d "$code/crates/core" ] || { echo "Set CODE_REPO to a checkout of dishant0406/akidev (not found: $code)" >&2; exit 2; }
[ $# -ge 1 ] || { echo "usage: check-source.sh <file> [module.wasm]" >&2; exit 2; }

file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
module=""
[ $# -ge 2 ] && module="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
cd "$code"

if jq -e 'has("plugin")' "$file" > /dev/null 2>&1; then
  test_file="crates/core/tests/zz_plugin_check_tmp.rs"
  trap 'rm -f "$test_file"' EXIT
  cat > "$test_file" <<'RS'
#[test]
fn the_plugin_is_accepted() {
    let path = std::env::var("PLUGIN_FILE").unwrap();
    let mut plugin = akidev_core::plugin::parse(&std::fs::read(&path).unwrap())
        .unwrap_or_else(|error| panic!("PLUGIN REFUSED: {error:#}"));
    if let Ok(module) = std::env::var("PLUGIN_MODULE") {
        plugin
            .attach(&std::fs::read(module).unwrap())
            .unwrap_or_else(|error| panic!("MODULE REFUSED: {error:#}"));
    }
    println!(
        "PLUGIN OK: {} ({} indexers, {} catalogues, {} services, module checked: {})",
        plugin.id,
        plugin.indexers.len(),
        plugin.providers.len(),
        plugin.services.len(),
        std::env::var("PLUGIN_MODULE").is_ok()
    );
}
RS
  if [ -n "$module" ]; then
    out="$(env PLUGIN_FILE="$file" PLUGIN_MODULE="$module" cargo test -q -p akidev-core --features code-plugins --test zz_plugin_check_tmp -- --nocapture 2>&1 || true)"
  else
    out="$(env PLUGIN_FILE="$file" cargo test -q -p akidev-core --features code-plugins --test zz_plugin_check_tmp -- --nocapture 2>&1 || true)"
  fi
  echo "$out" | grep -E "PLUGIN OK|REFUSED|panicked|^error" || echo "$out" | tail -5
  echo "$out" | grep -q "PLUGIN OK" || exit 1
elif jq -e 'has("schema")' "$file" > /dev/null 2>&1; then
  cargo run -q -p akidev-core --bin akidev-sources -- check "$file"
else
  # One entry: work out what it is, put it into a copy of the document, and check the copy.
  section="$(jq -r 'if has("tabs") then "screens"
    elif has("file_hosts") and has("request") then "subtitles"
    elif has("base_url") and has("card") then "providers"
    elif has("provider") and has("kinds") then "mappers"
    elif has("hosts") and has("request") and has("response") then "indexers"
    else "unknown" end' "$file")"
  [ "$section" != "unknown" ] || { echo "Cannot tell what kind of entry this is (an indexer, provider, subtitle source, mapper, screens, or a plugin)." >&2; exit 1; }
  copy="$(mktemp)"
  trap 'rm -f "$copy"' EXIT
  if [ "$section" = "screens" ]; then
    jq --slurpfile entry "$file" '.screens = $entry[0]' "$sources_repo/sources.json" > "$copy"
  else
    jq --arg section "$section" --slurpfile entry "$file" \
      '.[$section] = ((.[$section] // []) | map(select(.id != $entry[0].id))) + [$entry[0]]' \
      "$sources_repo/sources.json" > "$copy"
  fi
  echo "Checking it as an entry of $section in a copy of sources.json ..."
  cargo run -q -p akidev-core --bin akidev-sources -- check "$copy"
fi
