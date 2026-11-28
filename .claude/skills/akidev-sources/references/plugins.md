# Plugins

A plugin is how a **user** adds sources of their own without touching `sources.json`. It is one JSON file, plus an optional `.wasm` file. Only the desktop app loads plugins. The server and the website never do. Nobody signs a plugin, so it is shown as "unverified" and is held to stricter rules than the signed document.

Code: `<code repo>/crates/core/src/plugin.rs` (rules, install), `code.rs` (the WebAssembly sandbox), `services.rs` (stream services). Notes: `<code repo>/pipeline/WASM_PLUGINS.md`.

## Contents

1. Where plugins live and how users add them
2. The rules every plugin follows
3. What a plugin can bring
4. Catalogues (providers) in a plugin
5. Kinds in a plugin
6. Mappers in a plugin
7. Code plugins (WebAssembly)
8. Stream services
9. Write, build and hash a module
10. Test a plugin
11. What a plugin cannot do

---

## 1. Where plugins live and how users add them

- Folder: `<app data folder>/plugins`.
- `name.json` is on. `name.json.off` is off. A module sits beside it as `<id>.wasm`.
- Settings, **Plugins**: add by https link (fetched once, never redirected, 256 KB at most, and the module is fetched from the **same host**, next to the JSON), switch on or off, remove, reload (picks up files put in the folder by hand).
- To update a plugin the user adds its link again.
- Installing checks the plugin, writes it, and loads it. If it would stop another plugin working, or is invalid, everything is rolled back.
- The settings file is `config.toml` in the same folder. It holds each stream service's key and is readable only by its owner.

## 2. The rules every plugin follows

- `plugin` must be `1`.
- `id`: 1 to 40 lower case letters, digits or dashes, and it is the file name. `name`: 1 to 60 characters. `version`: a number.
- The whole file is at most 256 KB. It must bring at least one thing.
- **Every address** is `https`, on a public host name, with no login in it and no port. Not an IP address. Not `localhost`. Not a name ending in `.local`, `.localdomain`, `.localhost`, `.internal`, `.intranet`, `.private`, `.corp`, `.home`, `.lan` or `.home.arpa`. A public name that points to a private address is not caught.
- These headers may not be set: `host`, `content-length`, `transfer-encoding`, `connection`, `upgrade`, `te`, `trailer`, `expect`.
- A plugin adds sources **after** the built-in ones and can never replace one: an id that is already taken is refused.
- A plugin may use a kind only if it always exists or the plugin brings it.

## 3. What a plugin can bring

| Key | What | Limit |
| --- | --- | --- |
| `indexers` | Torrent sites (same shape as in the document) | 16 |
| `subtitles` | Subtitle sources | 4 |
| `providers` | Catalogues | 4 |
| `home` | Home page rows from the plugin's own catalogues | 8 |
| `kinds` | New kinds with tabs | 4 |
| `mappers` | Id mappers | 2 |
| `services` | Stream services (need `module`) | 2 |
| `module` | A WebAssembly file | 4 MB |

Smallest plugin:

```json
{
  "plugin": 1,
  "id": "my-torrents",
  "name": "My torrents",
  "version": 1,
  "indexers": [
    {
      "id": "my-torrents-api",
      "name": "My torrents",
      "kinds": ["series"],
      "hosts": ["https://torrents.example.com/api"],
      "request": { "path": "/search", "query": { "q": "{term}" } },
      "response": { "format": "json", "rows": "items", "fields": { "title": "title", "hash": "hash" } }
    }
  ]
}
```

## 4. Catalogues (providers) in a plugin

- `id`: 1 to 24 lower case letters or digits (no dash).
- Every address (`base_url`, `image_hosts`) follows the https rule.
- Titles carry their provider in the key: `series-myprovider~abc_2d12` is the title `abc-12` of `myprovider`. Every character of the service's id that is not a letter or digit becomes `_` and two hex digits. So they never clash with built-in ids.
- The app makes the episode ids. The provider's `episodes.id` is not used for the key.
- A plugin catalogue is not in a chain and has no tab. Its titles are added to every search, after the built-in results.
- `home` rows: `{ "title", "kind", "sort", "provider" }`. `provider` is required and must be one of the plugin's own catalogues that serves the kind.

## 5. Kinds in a plugin

```json
{ "id": "documentary", "label": "Documentaries", "singular": "Documentary", "shape": "series" }
```

- `id`: 1 to 16 lower case letters, not an existing kind.
- `label` and `singular`: 1 to 30 characters. `singular` defaults to the label.
- `shape`: `series`, `anime` or `movie`. The three shapes are engine code. A fourth is not possible from a plugin.
- The kind gets a tab. Its tab lists from the plugin's own catalogue. A kind stays known after the plugin is removed, so saved titles still read.

## 6. Mappers in a plugin

Same shape as in the document. An indexer of the plugin names one with `map`. Holes: `{<id>}` and `{<id>_kind}`. A mapper cannot take the id of one that already exists. At most 2.

## 7. Code plugins (WebAssembly)

For what JSON cannot say: signing a request, a login, reading an HTML page.

```json
{
  "plugin": 1,
  "id": "signed-torrents",
  "name": "Signed torrents",
  "version": 1,
  "module": { "file": "signed-torrents.wasm", "sha256": "<64 lower case hex digits>" },
  "indexers": [
    {
      "id": "signed-torrents",
      "name": "Signed torrents",
      "kinds": ["series"],
      "hosts": ["https://torrents.example.com"],
      "code": "search",
      "request": { "path": "/list", "query": { "q": "{term}" } },
      "response": { "format": "json", "rows": "items", "fields": { "title": "title", "hash": "hash", "seeders": "seeders" } }
    }
  ]
}
```

- `module.file`: a plain lower case name ending in `.wasm` (letters, digits, `-`, `_`, `.`; 6 to 60 characters; not starting with a dot). `module.sha256`: 64 lower case hex digits.
- The module must be a real WebAssembly file (starts with `\0asm`), at most 4 MB, and match its hash.
- An indexer, a provider, or a mapper's provider names an export in `code` (1 to 32 lower case letters, digits or `_`). A module that nothing uses is refused, and a source that asks for `code` needs the module.
- **The idea:** the module replaces only the request step. It makes the requests and answers with JSON. The source's own `response` (or `card`, `list`, `detail`) then reads that JSON like any other answer. So the hash check, the episode rules and the ranking still apply.
- The app builds with the Cargo feature `code-plugins` (the desktop app turns it on). A build without it refuses a plugin that has a `module`.

### The sandbox

- No files. No clock. No network except `akidev.http`.
- Per call: 300 million instructions, 64 MB of memory, 20 seconds, 8 requests, answers up to 2 MB, input and output up to 2 MB.
- `akidev.http` only reaches the hosts the source declares, over public https. Redirects to private hosts are refused. The forbidden headers are refused.
- Signing and HTML parsing are compiled **into** the module. The app offers no crypto and no parser.

### The interface

JSON in, JSON out, over the module's memory.

- **Exports:** `memory`; `alloc(len: i32) -> i32`; and one function per job: `fn(ptr: i32, len: i32) -> i64`, returning `(ptr << 32) | len` of the JSON it wrote.
- **Imports (module `akidev`):** `http(ptr, len) -> i64` and `log(ptr, len)`.
- `http` takes `{ "method": "GET", "url": "...", "headers": {}, "body": "..." }` and returns `{ "status": 200, "body": "..." }`, or `{ "error": "..." }` when the request is refused or fails. Only `GET` and `POST`.

An indexer's job is called with `{ "host", "kind", "path", "query", "json" }` (the filled request, as hints). A provider's job is called with `{ "method", "url", "query", "json" }`.

A working example is `content/plugins/code-indexer` in the code repo's git history (`git show 5779987^:content/plugins/code-indexer/...`; the folder was removed from the tree) (it signs a request with a hash of a shared secret and reads an HTML page into rows).

## 8. Stream services

A stream service turns a release into a playable https link, like a debrid service. It needs `module`.

```json
{
  "plugin": 1,
  "id": "torbox",
  "name": "TorBox",
  "version": 1,
  "module": { "file": "torbox.wasm", "sha256": "<64 lower case hex digits>" },
  "services": [
    {
      "id": "torbox",
      "name": "TorBox",
      "export": "resolve",
      "base": "https://api.torbox.app/v1/api/torrents",
      "hosts": ["api.torbox.app"],
      "media_hosts": ["tb-cdn.pw", "tb-cdn.io"],
      "key_label": "TorBox API key"
    }
  ]
}
```

| Field | Rule |
| --- | --- |
| `id` | 1 to 24 lower case letters, digits or dashes. Settings keeps the key under it. |
| `name` | 1 to 40 characters. |
| `export` | 1 to 32 lower case letters, digits or `_`. Default `resolve`. |
| `base` | https address of the API, passed to the module. Must be on one of `hosts`. |
| `hosts` | 1 to 4 bare public host names the module may call. |
| `media_hosts` | 1 to 4 bare public host names the link may be on (subdomains match). |
| `key_label` | 1 to 40 characters. Absent means no key. |

### The protocol

At play time, enabled services are asked **before** the torrent engine, for the best 4 releases, for 20 seconds in total. A service that needs a key and has none is skipped.

The app calls the export with `{ "base", "key", "want", "release": {"hash", "magnet", "title", "file_idx"}, "media": {"title", "year", "season", "episode"}, "file", "state" }`.

1. `want: "files"`. The module answers:
   - `{ "status": "files", "files": [ { "id": "7", "name": "Show.S01E05.mkv", "size": 900000000 } ], "state": { ... } }`, or
   - `{ "status": "unavailable", "reason": "not cached" }`.
2. **The app picks the episode's file** from that list, with its own code (`releases::pick_for_identity`, the same code the server's debrid source uses). A module never decides which file is the episode.
3. `want: "link"` with `file: { "id": "..." }` and the `state` from step 1. The module answers `{ "status": "ready", "url": "https://..." }`.
4. At any step the module may answer `{ "status": "retry", "after_ms": 700, "state": { ... } }`. The app waits (at most 5 seconds each time, at most 40 calls) and calls again with the `state` it was given. A module has no clock, so the app does the waiting.

The link must be https, on a public host, and on one of `media_hosts`. It is handed to the player as it is and never stored. There are no request headers yet, so a link must carry its own token (TorBox's does).

The key: typed in Settings, **Stream services**. Kept in `config.toml` (owner-only). Given only to that service's module.

A working example is `content/plugins/torbox` in the code repo's git history (`git show 5779987^:content/plugins/torbox/...`); the built `plugins/torbox.json` and `.wasm` are in this repo.

## 9. Write, build and hash a module

The examples are Rust crates that build to WebAssembly, each its own workspace:

```bash
rustup target add wasm32-unknown-unknown
git -C <code repo> worktree add /tmp/plugin-src 5779987^   # the sources were removed from the tree
cd /tmp/plugin-src/content/plugins/code-indexer      # or torbox
cargo build --release --target wasm32-unknown-unknown
shasum -a 256 target/wasm32-unknown-unknown/release/code_indexer.wasm
```

Put the hash in the plugin's `module.sha256`. Host the JSON and the `.wasm` side by side on one https host.

Authoring tips:

- Keep the module small (`opt-level = "s"`, `lto = true`, `strip = true`).
- Compile signing and HTML parsing into the module.
- Return JSON the source's `response` can read. For an indexer, the rows and the field names it declares.
- Never send the user's key anywhere but the declared hosts.

## 10. Test a plugin

- **Rules:** put the JSON through the engine's checker. In the code repo, `plugin::parse` runs every rule. The tests in `crates/core/src/plugin.rs` show how.
- **A code plugin end to end:** the code repo's test `an_indexer_whose_requests_are_made_by_a_plugins_code_finds_releases` runs the example module against a signing server. Run it with:

  ```bash
  cd <code repo>
  cargo test -p akidev-core --features code-plugins an_indexer_whose_requests
  ```

- **A stream service:** `cargo test -p akidev-core --features code-plugins services::` runs the TorBox module against a fake TorBox.
- **By hand:** add the plugin in the desktop app's Settings, then check the plugin row for a problem message. A missing or changed module shows as a problem and the plugin is not used.

## 11. What a plugin cannot do

- Run on the website or the server.
- Add a fourth shape, or replace a built-in source or kind.
- Use a private address, a port, or a redirect.
- Touch files or the clock, or reach hosts it did not declare.
- Put a key anywhere but Settings.
- Change how releases are ranked or how an episode is matched (code, not data).
