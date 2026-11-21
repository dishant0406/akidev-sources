#!/usr/bin/env bash
#
# Runs one export of a code plugin's module against the real site and prints what it answers.
#
#   scripts/try-module.sh <module.wasm> <export> '<input json>' <host[,host...]>
#
# For an indexer module (the app calls it with the filled request as hints):
#   scripts/try-module.sh out/my-site.wasm search \
#     '{"host":"https://torrents.example.com","kind":"series","path":"/search","query":[["q","breaking bad"]],"json":null}' \
#     torrents.example.com
#
# For a catalogue module:  '{"method":"GET","url":"https://api.example.com/search","query":[["q","dune"]],"json":null}'
# For a stream service:    '{"base":"https://api.example.com/v1","key":"KEY","want":"files","release":{"hash":"...","magnet":"magnet:?xt=urn:btih:...","title":"..."},"media":{"title":"Show","year":null,"season":1,"episode":5},"state":null}'
#
# The module runs in the same sandbox as in the app, with the same limits and the same rules: public https
# hosts only, and only the hosts you list. Its requests are REAL requests to the site. Nothing is installed or
# published. Needs the code repo (CODE_REPO, or ../akidev next to this repo) and the wasm file.

set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
sources_repo="$(cd "$here/../../../.." && pwd)"
code="${CODE_REPO:-$sources_repo/../akidev}"
[ -d "$code/desktop/core" ] || { echo "Set CODE_REPO to a checkout of dishant0406/akidev (not found: $code)" >&2; exit 2; }
[ $# -eq 4 ] || { echo "usage: try-module.sh <module.wasm> <export> '<input json>' <host[,host]>" >&2; exit 2; }

module="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
export_name="$2"
input="$3"
hosts="$4"
echo "$input" | jq -e . > /dev/null || { echo "The input is not valid JSON." >&2; exit 2; }

cd "$code/desktop"
test_file="core/tests/zz_try_module_tmp.rs"
trap 'rm -f "$test_file"' EXIT
cat > "$test_file" <<'RS'
#[tokio::test(flavor = "multi_thread")]
async fn run_the_module() {
    let module = std::fs::read(std::env::var("TRY_MODULE").unwrap()).unwrap();
    let export = std::env::var("TRY_EXPORT").unwrap();
    let input: serde_json::Value = serde_json::from_str(&std::env::var("TRY_INPUT").unwrap()).unwrap();
    let hosts: Vec<String> = std::env::var("TRY_HOSTS").unwrap().split(',').map(str::to_string).collect();
    match akidev_core::code::run(module, &export, input, hosts, akidev_core::code::Limits::default()).await {
        Ok(answer) => println!("MODULE ANSWER:\n{}", serde_json::to_string_pretty(&answer).unwrap()),
        Err(error) => println!("MODULE FAILED: {error:#}"),
    }
}
RS
out="$(env TRY_MODULE="$module" TRY_EXPORT="$export_name" TRY_INPUT="$input" TRY_HOSTS="$hosts" \
  cargo test -q -p akidev-core --features code-plugins --test zz_try_module_tmp -- --nocapture 2>&1 || true)"
echo "$out" | sed -n '/MODULE ANSWER:/,/^test result/p;/MODULE FAILED/p' | grep -v -E "^test result|^\.$" | head -${LINES_SHOWN:-60}
echo "$out" | grep -q -E "MODULE ANSWER|MODULE FAILED" || { echo "$out" | tail -15; exit 1; }
echo "$out" | grep -q "MODULE FAILED" && exit 1 || true
