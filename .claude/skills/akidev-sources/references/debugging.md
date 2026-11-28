# Debugging

Start with the symptom. Then try the real request by hand.

## Contents

1. Symptom to cause table
2. Reproduce a request by hand
3. Read what the engine did
4. Run the server locally
5. Check what is live
6. A plugin does not work

---

## 1. Symptom to cause

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| `check` refuses the file with "appears twice" | Two entries share an id | Make ids unique. |
| `check`: "does not start at the base address" | A provider `url` does not begin with `{base}/` | Put `{base}` first. |
| `check`: "its request cannot be filled in for X" | A hole is misspelt, or needs a value the kind does not have | Check hole names. For `anime`, `{imdb}` may be empty: use `{imdb_or_term}` or a mapper. |
| `check`: bad pattern | A regex does not compile | Fix it (Rust `regex` syntax). |
| `check`: "names an unknown provider" or "does not serve" | A chain lists a provider that does not exist or does not serve that kind | Fix the chain or the provider's `kinds`. |
| `check`: "the tab slug ... is already a page of the site" | Slug is `search`, `title`, `watch`, `download`, `privacy`, `manga` or `info` | Pick another slug. |
| `check`: a home row names a provider that does not serve its kind | Row `provider` or `kind` is wrong | Fix the row. |
| Publish refused: not newer | `version` is not above the live one (the tracker job raises it daily) | Check the live version and set a higher one. |
| Old-app check refused it | A value old apps do not know | Ship the app first and set `OLD_REF`, or avoid the new value. |
| An indexer finds nothing | Wrong `rows` path or field paths, or a hole that is empty so the request is never made | Run the request with `curl` and compare the real answer with the definition. |
| An indexer's request is never made | It needs `{imdb}` (or a mapped id) and the title has none | Use `{imdb_or_term}`, or add a second indexer that works by name. |
| Rows come back but few survive | `drop`, `must_contain_term`, or ranking filtered them | Loosen `drop`. Ranking is code: see `engine.md`. |
| A catalogue row is empty | `drop` is too strict, `paging` is wrong, or the answer is an error | Check `drop` and `paging`. Add a `check` to turn an error answer into a real error. |
| A catalogue spells genres differently | `screens.genres` uses another provider's spelling | Use each provider's own spelling. |
| Pictures do not show on the website | The picture host is not in `image_hosts` | Add the bare host to the provider's `image_hosts`. |
| Subtitle files are refused | The file's host is not in `file_hosts` | Add the bare host. |
| A new field is ignored by users | Their app predates the field | Publish first, then ship the app. |
| The footer or privacy page names a source that is gone | `screens.about` was not updated | Edit `screens.about`. |
| Anime episodes are not found by Torrentio | The mapper returned no exact same-number episode | Check the mapper's `episodes` and the `id_pattern`. The indexer is skipped on purpose when there is no exact mapping. |
| "busy" when playing on the web | A server limit was hit (searches, torrents, video sessions) | Not a sources problem. The server now logs which limit. See `engine.md`. |
| Works in `check`, not for users | The check cannot know if a mirror is alive, if a GraphQL selection is right, or if an episode is the right one | Test against the real service. |

## 2. Reproduce a request by hand

An **indexer**: build the URL from `hosts[0]` + `request.path` + `request.query`, with the holes filled in.

```bash
# GET
curl -s 'https://nyaa.si/?page=rss&q=frieren&c=1_0&f=0' | head -40

# POST with a JSON body
curl -s -X POST 'https://api.knaben.org/v1' \
  -H 'content-type: application/json' \
  -d '{"search_type":"100%","search_field":"title","query":"frieren","size":50,"order_by":"seeders","order_direction":"desc"}' | jq '.hits[0]'

# a Stremio addon, by IMDb id, season and episode
curl -s 'https://torrentio.strem.fun/stream/series/tt0903747:1:5.json' | jq '.streams[0]'
```

A **provider**: `url` with `{base}` replaced by `base_url`. For a GraphQL provider, send the `query` and `variables` from the request's `json`.

Then check each path in the definition against the real answer with `jq`, for example `jq '.data.movies[0].torrents[0].hash'`.

If the service is down or blocks you, say so. A definition cannot be proven without a live answer.

## 3. Read what the engine did

Run the server locally (below) with debug logging, then ask for a play. The search logs lines like:

```text
[search] series: 36 of 39 requests answered in 1.99s, stopped on enough, after the grace; first playable after 1.28s; 4 releases; per index...
[stream] series-tt33094114-s1e1: title after 187ms, releases after 2.0s more: 1 playable, 0 others
```

`provider request failed indexer=<id>` means an indexer's request failed. `mirror request failed` is one mirror, not the whole indexer. Set `RUST_LOG=akidev_core=debug,akidev_server=debug` for detail.

The server's `GET /health` shows slots in use, open video sessions, active torrents, whether TorBox is reachable, and play counts.

## 4. Run the server locally

```bash
cd <code repo>
cp "$SOURCES_DIR/sources.json" sources/sources.json
PORT=9187 CACHE_DIR="$(mktemp -d)" STREAM_SOURCES=torrent LISTEN_PORT=6991 \
  RUST_LOG=akidev_core=debug,akidev_server=debug cargo run -p akidev-server
```

In another terminal:

```bash
curl -s localhost:9187/v1/screens | jq '.tabs'
curl -s 'localhost:9187/v1/search?q=frieren' | jq '.results[0]'
curl -s -X POST localhost:9187/v1/play -H 'content-type: application/json' \
  -d '{"id":"series-tt0903747-s1e1","hevc":false}'
```

Without TorBox the debrid source says "not configured". A torrent that cannot be opened on your machine ends with "Found releases, but none could be played": finding releases worked. Stop the server and delete the temp folder when you are done. Do not leave a server running.

## 5. Check what is live

```bash
curl -s https://sources.akidev.live/sources.json | jq '[.version, .schema, (.indexers|length), (.providers|length)]'
curl -s https://sources.akidev.live/v2/sources.json | jq '[.version, .schema]'
curl -s https://api.akidev.live/v1/screens | jq '.tabs[0], .about'
curl -s https://api.akidev.live/health | jq .
```

The server's `/v1/screens` follows the document it has loaded, so it lags a publish by up to about 6 hours.

## 6. A plugin does not work

- Open Settings, Plugins. A plugin with a problem shows the reason in its row. Common reasons: a rule was broken (an https address, a header, an id), the file name is not `<id>.json`, the module is missing or its hash differs, or it would stop another plugin working.
- A plugin with a `module` only runs in a build with the `code-plugins` feature (the desktop app has it).
- A module that traps, loops or exceeds a limit gives an empty answer for that source, and the log shows why at debug level. Run the code plugin test (`plugins.md`, section 10) to see the module run against a local server.
- A stream service that needs a key and has none is skipped silently. Check Settings, Stream services.
- A link a service returns must be https, public, and on a host in `media_hosts`, or it is refused.
