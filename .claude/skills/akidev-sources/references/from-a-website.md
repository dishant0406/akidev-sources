# From a website to a working source

This is the playbook for the most common request: **the user gives you a website, an API, a feed or an idea, and you write the whole thing**: the JSON, and the code if JSON cannot say it. Follow it in order. Every step has a command or a template.

Paths below are relative to the skill folder (`.claude/skills/akidev-sources/`). `scripts/` and `templates/` are in it. `<code repo>` is a checkout of `dishant0406/akidev` (set `CODE_REPO`, or keep it next to this repo as `../akidev`).

## Contents

0. The job, and what you hand back
1. Before you start: questions and limits
2. Investigate the site
3. Decide what to build
4. Turn the answer into a definition
5. Write it from a template
6. Test it
7. When JSON is not enough: a code plugin (HTML scraping, signing, a login)
8. A debrid-style service: a stream service plugin
9. Deliver it
10. Worked examples
11. Pitfalls
12. The final report

---

## 0. The job, and what you hand back

You are turning "this site" into one of these:

| The site is | You write | Goes in |
| --- | --- | --- |
| A torrent site or addon with a JSON, RSS, Torznab or Stremio answer | an **indexer** | `sources.json` (maintainer) or a **plugin** (a user) |
| A catalogue of titles (a metadata API) | a **provider** (and a `chains` entry, `screens` credits) | `sources.json` or a **plugin** |
| A subtitle site | a **subtitle source** | `sources.json` or a **plugin** |
| A service that maps one id to another | a **mapper** | `sources.json` or a **plugin** |
| A site that is only HTML, or needs signing or a login | a **code plugin** (an indexer or catalogue whose module reads the page) | a **plugin** (JSON + `.wasm`) |
| A debrid-style service that turns a release into a link | a **stream service plugin** | a **plugin** (JSON + `.wasm`) |
| Music, ranking rules, a new shape, anything that needs a secret on the server | **code**, not data | tell the user (see `references/engine.md`) |

**Where does it go?**

- The user maintains Akidev (they own `sources.json` and can publish): put it in `sources.json`. Everyone gets it.
- The user only wants it for themselves, or cannot publish, or the source needs a key: make a **plugin**. Plugins are desktop-app only.
- When unsure, ask one question: "Do you want this for everyone (it goes in sources.json and you publish it), or just for your own app (a plugin)?"

What you hand back: the finished JSON (and `.wasm` if any), what you tested and how, how to install it, and what you could not verify.

## 1. Before you start: questions and limits

Ask only what you cannot find out yourself. Usually just: the site or API address, whether it is for everyone or for the user, and (if it needs one) how the user will supply a key.

**Keys and passwords.** Never ask the user to paste a password or a secret key into the chat, and never write one into `sources.json` (it is public) or into a file in a repo. For a plugin that needs a key: an indexer plugin's key can sit in its own `request.query` or `request.json` (the file is the user's own, and it is plain text, so tell them); a stream service's key is typed in Settings. To test with a key, ask the user to run the test command themselves, or to set an environment variable for the command. Do not echo it back.

**Respect the site.** Use public endpoints the site offers (an API, an RSS feed, a Torznab feed, a Stremio addon, a normal search page). Do **not** try to get around protections. If the site answers with a challenge page (for example Cloudflare's "Just a moment", a captcha, a login wall, a 403 for automated clients), stop and tell the user: data and plugins cannot solve those, and a source that needs them is not supported. Do not rotate fake browser headers or hammer the site to find a way in.

**Be gentle while investigating.** A handful of requests, not hundreds. Save what you fetch.

## 2. Investigate the site

Make a scratch folder and save everything you fetch, so you never ask twice and so you have test fixtures:

```bash
mkdir -p /tmp/new-source && cd /tmp/new-source
curl -s -L -D headers.txt -A 'Mozilla/5.0' 'https://example.com/' -o home.html
head -20 headers.txt        # status, content-type
```

### What kind of answer is it?

| You see | It is | Next |
| --- | --- | --- |
| `content-type: application/json`, or the body starts with `{` or `[` | A JSON API | Find the search request (below). |
| `application/rss+xml`, or the body has `<rss` or `<channel>` | An RSS feed | Pattern: Nyaa. Rows are the `<item>`s. |
| `https://site/api?t=caps` answers XML with `<caps>` | **Torznab** (Jackett, Prowlarr, many indexers) | `templates/indexer-torznab.json`. |
| `https://site/manifest.json` answers JSON with `resources` and `types` | A **Stremio addon** | `resources` of `stream` means an indexer; `catalog` and `meta` mean a catalogue; `subtitles` means a subtitle source. |
| `https://site/graphql` answers a POST | **GraphQL** | `templates/provider-graphql.json`. |
| Only HTML (a search page with a results table) | HTML | See whether there is an API behind it (below). If not, a **code plugin** (section 7). |
| A challenge page, captcha or login wall | Protected | Stop (section 1). |

### Find the API behind an HTML site

Most search pages call a JSON endpoint. Look for it in the page:

```bash
grep -o -E '(fetch|axios[.a-z]*|\$\.(get|ajax))\([^)]{0,120}' home.html | head
grep -o -E '"/[a-z0-9_/.-]*(api|search|q\.php|list|torrents)[a-z0-9_/.?=&-]*"' home.html | sort -u | head -20
grep -o -E 'src="[^"]*\.js[^"]*"' home.html | head      # then grep those scripts for "/api/"
curl -s https://example.com/robots.txt | head
for path in /api /api/v1 /openapi.json /swagger.json /docs /graphql /manifest.json /rss /feed; do
  printf "%s -> " "$path"; curl -s -o /dev/null -w '%{http_code}\n' -A 'Mozilla/5.0' "https://example.com$path"
done
```

### Find the search request

Try the obvious search parameters and keep the one that works:

```bash
for p in q query search s keyword name; do
  printf "%s: " "$p"; curl -s -A 'Mozilla/5.0' "https://example.com/api/search?$p=breaking+bad" | head -c 120; echo
done
```

Then look at one real answer closely and save it:

```bash
curl -s -A 'Mozilla/5.0' 'https://example.com/api/search?q=breaking+bad' -o answer.json
jq . answer.json | head -60
jq 'keys' answer.json                       # where are the rows?
jq '.results | length' answer.json          # how many rows
jq '.results[0]' answer.json                # one row, with every field
```

Also find out:

- **Does it have an info hash?** A 40 hex digit (or 32 base32) `info_hash` or `hash`, or a magnet link (`magnet:?xt=urn:btih:...`) you can take the hash from. **A row with neither cannot be used.** A site that only links `.torrent` files is not supported cheaply.
- **How are seeders, size and categories given?**
- **Is there a limit parameter?** Ask for 50 to 100.
- **Are there categories** that separate anime, series and films? You will use `$kind`.
- **Other domains** (mirrors) of the same service: list them for `hosts`.
- **How does it treat a title with an IMDb id?** Some APIs take `imdb_id` (EZTV, YTS, Torrentio). Use `{imdb}` or `{imdb_digits}` there.
- **Does a successful empty answer leave the list out?** Then you need `empty_when`.
- **Does the site rate-limit?** Use `min_interval_secs` or `max_requests_per_day`.
- **Does the site need a header** (a user agent, a key)? Put it in `request.headers`.

## 3. Decide what to build

```text
Is there a JSON, RSS, Torznab or Stremio answer you can call without a login?
 ├─ yes
 │   ├─ it lists torrents ................................ an INDEXER (section 4, 5)
 │   ├─ it lists titles (posters, years, episodes) ....... a PROVIDER, plus a chains entry
 │   ├─ it lists subtitle files .......................... a SUBTITLE SOURCE
 │   └─ it turns one catalogue's id into another's ....... a MAPPER
 └─ no
     ├─ only HTML ....................................... a CODE PLUGIN (section 7)
     ├─ needs signing, a login or a cookie ................ a CODE PLUGIN (section 7), the user supplies the value
     ├─ it is a debrid-style service (add a magnet, get a link) ... a STREAM SERVICE PLUGIN (section 8)
     └─ it is behind a challenge or a captcha ............ not supported: tell the user
```

Then pick the place: `sources.json` (for everyone) or a plugin (for one user). Code and stream services are always plugins.

## 4. Turn the answer into a definition

### Indexer: what to write

1. **`rows`**: the path to the list. `results`, `data.movies`, `torrents`, `hits`, `streams`. If the body *is* the list, use `""`. If rows are values of an object, use `torrents.*`.
2. **Fields** (the first two are required):

   | You see in a row | Write |
   | --- | --- |
   | `"name": "Show S01E05 1080p"` | `"title": "name"` |
   | `"info_hash": "ABC..."` | `"hash": "info_hash"` (any case is fine) |
   | only `"magnet": "magnet:?xt=urn:btih:..."` | `"hash": {"magnet_hash": "magnet"}` and `"magnet": "magnet"` |
   | `"size": "1.3 GB"` or bytes | `"size": "size"` |
   | size in KiB (`"size_kb": 1300000`) | `"size": {"scale": {"from": "size_kb", "by": 1024}}` |
   | `"seeders": "12"` (text) | `"seeders": "seeders"` (text numbers are read) |
   | seeders buried in text (`"👤 12"`) | `"seeders": {"regex": {"from": "title", "pattern": "👤\\s*([0-9]+)"}}` |
   | title in two keys | `{"coalesce": ["title", "description"]}` |
   | title with the year from the parent row (nested) | `{"template": "{^.title}{? ({^.year})?}"}` with `children` |
   | HTML in the text | `{"plain_text": "name"}` |
   | a hash that is all zeros for "no result" | a `drop`: `{"path": "info_hash", "equals": "0000000000000000000000000000000000000000"}` |

3. **The request.** Put the real parameters in `query` (GET) or `json` (POST) with holes:
   - `{term}` for the search text. The app builds several terms (the title, other names, with and without episode tokens), so you usually only need `{term}`.
   - `{imdb}`, `{imdb_digits}` (`tt0903747` or `0903747`), `{imdb_or_term}` when the site takes an IMDb id.
   - `{season}`, `{episode}` when the site wants them separately. They are plain numbers (not zero padded). If the site wants `S01E05` text, use `{term}` instead: the app already tries those forms.
4. **Separate the kinds** with `{"$kind": {"anime": ..., "series": ..., "movie": ...}}` where the site has categories, and set `kinds` to the ones the site really serves.
5. **`fanout`:**
   - `per-term` (default): the site searches by text.
   - `per-title`: the site answers with every episode of a show, or has no episode syntax.
   - `once`: the request does not use the term (an IMDb id does).
6. **Mirrors:** list the other domains in `hosts`, best first (up to 8).
7. **Empty answers:** if a successful empty answer leaves the list out or says `"status": "ok"` with a zero count, add `empty_when` (copy `yts`).
8. **Clean up:** `drop` for unwanted categories or placeholder rows; `must_contain_term: true` for a site with no category filter; `dedupe.avoid` if a bonus clip shares a hash with a pack.
9. Do **not** invent seeders. If the site omits them, leave `seeders` out.

### Provider (a catalogue): what to write

Walk the four questions, saving a real answer for each:

1. **A list** (`list`): the request for a page, the `rows` path, the `paging` style (`page` if it takes page numbers and says if there is a next one, `skip` if it takes an offset, `pool` if it returns everything). If it cannot filter by genre or year, filter here (`list.genre`, `list.year`, plus `widen` or `window`).
2. **A search** (`search`): the request and the `rows` path.
3. **One title** (`detail`): the request with `{id}`, the `root` path, `id_pattern`, and where the description, IMDb id, episodes (`rows`, `id`, `season`, `number`), cast and related titles are.
4. **A card** (`card`): the one place that says how any title is read (id, title, poster, year, score out of 100, genres).

Then: `image_hosts` (every host a poster is on), the `chains` entry (which kind, in what order, first or backup), `screens.about.catalogues` (the credit), and `screens.genres` (the provider's own spelling). Start from `templates/provider-rest.json` or `provider-graphql.json`, and compare with the real `tvmaze`, `anilist` and `cinemeta` entries in the live document.

### Subtitle source: what to write

Copy `templates/subtitle-stremio.json` (for a Stremio subtitles addon) and change the hosts, the request per kind, the `response.rows` and fields, and `file_hosts` (every host the files are on, as bare names). Add `lookup` only if the site is keyed by IMDb id and the title is anime.

### Check your paths against the saved answer before writing the file

You can try each path with `jq` on the saved real answer. A path that gives `null` here gives nothing in the engine.

```bash
jq '[.results[] | {t: .name, h: .info_hash, s: .size, sd: .seeders}] | .[0:3]' answer.json
jq '[.results[] | select(.info_hash == null)] | length' answer.json     # rows with no hash: will be dropped
```

## 5. Write it from a template

Copy the closest template and edit it. Do not write from nothing.

| Template | For |
| --- | --- |
| `templates/indexer-json-get.json` | A JSON search API called with GET. |
| `templates/indexer-json-post.json` | A JSON API called with POST and a body, with categories per kind. |
| `templates/indexer-rss.json` | An RSS feed (Nyaa style). |
| `templates/indexer-torznab.json` | A Torznab feed (Jackett, Prowlarr). |
| `templates/indexer-stremio-stream.json` | A Stremio stream addon. |
| `templates/provider-rest.json` | A REST catalogue. |
| `templates/provider-graphql.json` | A GraphQL catalogue. |
| `templates/subtitle-stremio.json` | A Stremio subtitles addon. |
| `templates/mapper.json` | An id mapper. |
| `templates/plugin-json.json` | A plugin with an indexer. |
| `templates/plugin-catalogue-kind.json` | A plugin with a catalogue, a new kind, a tab and a home row. |
| `templates/plugin-code-indexer.json` + `templates/guest-indexer/` | A code plugin that reads an HTML page. |
| `templates/plugin-service.json` + `templates/guest-service/` | A stream service (the TorBox module is the reference). |

```bash
cp templates/indexer-json-get.json /tmp/new-source/entry.json
$EDITOR /tmp/new-source/entry.json
```

Rules while editing: a unique lower case `id` with dashes; a human `name`; only the `kinds` the site serves; every address `https` (plugins: public https only, no port); keep JSON formatted with 2 spaces.

**Where the entry goes:**

- `sources.json`: add the entry to `indexers` (or `providers`, `subtitles`, `mappers`). A provider also goes in a `chains` list and its name in `screens.about`. Raise `version`.
- A plugin: start from `templates/plugin-json.json` (or the catalogue or code one), put the entry in `indexers` (or `providers`, `subtitles`), and set the plugin `id` (the file name), `name` and `version`.

## 6. Test it

Do all of these. A definition that passes the checker can still read nothing.

1. **The rules:**

   ```bash
   scripts/check-source.sh /tmp/new-source/entry.json        # an entry, checked inside a copy of sources.json
   scripts/check-source.sh path/to/sources.json              # a whole document
   scripts/check-source.sh path/to/plugin.json [module.wasm] # a plugin
   ```

   It exits 0 when the file is accepted and prints the reason when it is not.
2. **Your paths against the saved real answer** with `jq` (section 4).
3. **A real search through the real engine**, for an indexer in `sources.json` or a document:

   ```bash
   scripts/try-local.sh path/to/sources.json series-tt0903747-s1e5 movie-tt0111161
   ```

   It starts a local server with your document (nothing is published), asks for the releases of those titles, and prints how many releases each source found. Your indexer's `id` should appear with a number above zero for titles it should know. `anime-16498-ep1` is an anime episode. The first run compiles the server and takes a few minutes. It restores everything when it ends.
4. **A code plugin's module against the real site:** `scripts/try-module.sh` (section 7).
5. **Keep a fixture test** if the entry goes into `sources.json`: in the code repo, `desktop/core/src/indexers/extract.rs` tests call `run("<id>", &body, "term")` with a saved real body (providers: `desktop/core/src/providers/read_tests.rs`). Copy one and use your saved answer.

If a site is down, blocks you, or answers differently from a browser, say so. Do not fake a result.

## 7. When JSON is not enough: a code plugin

Use a **code plugin** when the site is only HTML, or needs a signature, a login or a cookie. The module replaces only the request step: it makes the request, reads the page, and answers with JSON rows. The plugin's own `response` then reads that JSON, so the engine's checks (a valid hash, the right episode, ranking) still apply to every row.

### Steps

1. **Look at the page source** for the results (`curl -s -A 'Mozilla/5.0' 'https://site/search?q=x' -o page.html`). Find:
   - what starts and ends **one result row** (for example `<tr class="result">` to `</tr>`),
   - where, inside a row, the **magnet link** (`href="magnet:?xt=urn:btih:..."`) or a hash, the **title**, the **size** and the **seeders** are.
   If the listing page has no magnet and no hash and you would need a second page per row, you can fetch a few detail pages (a module may make at most 8 requests per call) but a listing that carries the magnet is much better. A row with no hash is useless.
2. **Make the module.**

   ```bash
   cp -R templates/guest-indexer /tmp/new-source/my-site        # rename the package in Cargo.toml too
   cp templates/plugin-code-indexer.json /tmp/new-source/my-site.json
   ```

   Edit `src/lib.rs`, the three `TODO` places: the page address, what starts and ends a row, and where each value is. The module only uses `serde_json`, and the helpers `between`, `plain`, `info_hash` and `encode` are already there.
3. **Edit the plugin JSON:** the `id`, `name`, `hosts` (the site), `request.query` (the template reads `q`), and `module.file` (match the package name: `my-site` gives `my-site.wasm`).
4. **Build, hash and check:**

   ```bash
   scripts/build-plugin.sh /tmp/new-source/my-site /tmp/new-source/my-site.json /tmp/new-source/out
   ```

   It builds the module, writes the real `module.sha256` into `/tmp/new-source/out/<id>.json`, and checks the plugin with its module (`module checked: true`). If the build says the wasm32 target is missing, run `rustup target add wasm32-unknown-unknown`, or set `TOOLCHAIN=<a toolchain that has it>`.
5. **Run the module against the real site** and read the rows it returns:

   ```bash
   scripts/try-module.sh /tmp/new-source/out/my-site.wasm search \
     '{"host":"https://torrents.example.com","kind":"series","path":"/search","query":[["q","breaking bad"]],"json":null}' \
     torrents.example.com
   ```

   It makes real requests, in the same sandbox as the app. You should see `{"items": [{"title": ..., "hash": ..., "size": ..., "seeders": ...}]}` with real rows. Empty `items` means a marker is wrong: look at the page again. Repeat steps 2 to 5 until the rows are right.
6. **Check the sandbox limits:** at most 8 requests, 20 seconds, 300 million instructions, 64 MB, 2 MB answers. Only the hosts in `hosts`, over public https.

### What the module is given, and what it can use

- An **indexer** module is called with `{ "host", "kind", "path", "query", "json" }`: the filled request, as hints. `query` is a list of `[name, value]` pairs.
- A **catalogue** module is called with `{ "method", "url", "query", "json" }`.
- It has no files, no clock, and no network except `akidev.http`. Signing and HTML reading are compiled into the module.
- **A key for a code indexer:** the plugin's `request.headers` are not passed to the module. Put a user-supplied value in `request.query` or `request.json` (the module reads it from the input), and tell the user it is stored in plain text in their plugin file. Never in `sources.json`.
- A code plugin only runs in the **desktop app** (it has the `code-plugins` feature). The server and the website do not run it.

## 8. A debrid-style service: a stream service plugin

Use this when the service already holds releases and returns a **playable https link**: you give it a release (a hash or magnet), it lists files, and it gives a link to one file.

1. **Read the service's API docs.** You need three calls:
   - **List the files of a release** that the service holds (cached). If it has to add the magnet first, which call adds it, and does it have an "only if cached" option (so nothing slow is started)?
   - **Read the files back** until they are listed (a retry loop: the module answers `retry`, the app waits).
   - **Get a link to one file** (by its id).
2. **Find the hosts:** the API host (for `hosts`), and the host the final link is on (for `media_hosts`). Get the second from a real link.
3. **Find how it authenticates** (a header like `Authorization: Bearer KEY`, or a token in the address). The key is typed by the user in Settings and given to the module in the input as `key`.
4. **Copy the reference module:** `templates/guest-service/` is the real TorBox module. Replace its API calls with the service's. **Keep the protocol exactly:** the app calls the export with `want: "files"` and then `want: "link"`; answers are `files` (with `files: [{id, name, size}]` and a `state`), `ready` (with `url`), `retry` (with `after_ms` and `state`) or `unavailable` (with `reason`). The **app** picks which file is the episode: the module never does.
5. **Write the plugin:** copy `templates/plugin-service.json` and set `id`, `name`, `export` (`resolve`), `base` (the API address, on one of `hosts`), `hosts`, `media_hosts` and `key_label`.
6. **Build and check:** `scripts/build-plugin.sh <crate> <plugin.json> <out>`.
7. **Test against the real service, with the user's key, run by the user.** Ask the user to run:

   ```bash
   scripts/try-module.sh out/my-service.wasm resolve \
     '{"base":"https://api.example.com/v1","key":"THEIR-KEY","want":"files","release":{"hash":"<a real info hash>","magnet":"magnet:?xt=urn:btih:<hash>","title":"Show S01"},"media":{"title":"Show","year":null,"season":1,"episode":5},"state":null}' \
     api.example.com
   ```

   Do not ask them to paste the key to you.
8. The link must be https, on a public host, and on one of `media_hosts`. It is handed to the player as it is, so it should carry its own token (there are no request headers yet).

## 9. Deliver it

### Into sources.json

1. Add the entry. For a provider: add it to `chains`, add its name to `screens.about.catalogues` (a subtitle source: `screens.about.subtitles`), and check `screens.genres`.
2. **Raise `version`** above the live one (check: `curl -s https://sources.akidev.live/sources.json | jq .version`).
3. `scripts/check-source.sh sources.json` and `scripts/try-local.sh sources.json <ids>`.
4. Show the diff, say what users will get, and **publish only if the user asks** (`references/publishing.md`).

### As a plugin

You hand back `<id>.json` and, for a code plugin or a service, `<module.file>` (the `.wasm`), both from the `build-plugin.sh` output folder. Tell the user how to install:

- **Locally (simplest).** Copy the files into the app's plugins folder and press **Reload** in Settings, Plugins. On macOS:

  ```bash
  mkdir -p "$HOME/Library/Application Support/live.akidev.Akidev/plugins"
  cp /tmp/new-source/out/my-site.json /tmp/new-source/out/my-site.wasm "$HOME/Library/Application Support/live.akidev.Akidev/plugins/"
  ```

  On Windows and Linux, Settings shows the exact folder in the Plugins section ("Or put a .json file in ... and reload").
- **By link.** Host the JSON and the `.wasm` **side by side on one public https host**, and add the JSON's link in Settings, Plugins, Add. The app downloads the module from the same host.
- A plugin that needs a stream-service key: the user types it in Settings, **Stream services**.

Never leave a user's key in the files you hand back, and never commit one.

## 10. Worked examples

### A. A plain JSON search API (The Pirate Bay's API)

Investigation:

```bash
curl -s 'https://apibay.org/q.php?q=breaking+bad+s01e05&cat=0' | jq '.[0]'
# a result row has: id, name, info_hash, size (text, in bytes), seeders (text), and more
# with nothing found it answers ONE placeholder row:
#   {"id":"0","name":"No results returned","info_hash":"0000000000000000000000000000000000000000","size":"0","seeders":"0"}
```

The body is the list itself (no `rows`). The placeholder row has to be dropped, or it would look like a release. The finished entry (real, in the live document):

```json
{
  "id": "apibay",
  "name": "The Pirate Bay",
  "kinds": ["anime", "series", "movie"],
  "cooldown_secs": 300,
  "hosts": ["https://apibay.org"],
  "request": { "path": "/q.php", "query": { "q": "{term}", "cat": "0" } },
  "response": {
    "format": "json",
    "drop": [
      { "path": "name", "equals": "No results returned" },
      { "path": "info_hash", "equals": "0000000000000000000000000000000000000000" }
    ],
    "fields": { "title": "name", "hash": "info_hash", "size": "size", "seeders": "seeders" }
  }
}
```

Why each part: no `rows` because the body is the list; two `drop`s for the placeholder; `cooldown_secs` is longer because the site is touchy; no `fanout` because the default (`per-term`) is right.

### B. An RSS feed (Nyaa)

```bash
curl -s 'https://nyaa.si/?page=rss&q=frieren&c=1_0&f=0' | head -40
# each <item> holds <title>, <nyaa:infoHash>, <nyaa:size> (like "1.4 GiB") and <nyaa:seeders>
```

Tags are read by name (`nyaa:infoHash`), so the fields are `"hash": "nyaa:infoHash"`, `"size": "nyaa:size"`, `"seeders": "nyaa:seeders"`. Three mirrors are listed in `hosts`. The full entry is in the README under Indexers.

### C. An API keyed by IMDb id (EZTV)

```bash
curl -s 'https://eztv.yt/api/get-torrents?imdb_id=0903747&limit=100' | jq '.torrents[0]'
```

The site takes the IMDb id's digits, so the request uses `{imdb_digits}`, `fanout` is `per-title` (one answer holds every episode), and three mirrors are listed.

```json
{
  "id": "eztv",
  "name": "EZTV",
  "kinds": ["series"],
  "fanout": "per-title",
  "hosts": ["https://eztv.yt/api", "https://eztv1.xyz/api", "https://eztv.wf/api"],
  "request": { "path": "/get-torrents", "query": { "imdb_id": "{imdb_digits}", "limit": "100" } },
  "response": {
    "format": "json",
    "rows": "torrents",
    "fields": { "title": "filename", "hash": "hash", "size": "size_bytes", "seeders": "seeds" }
  }
}
```

### D. A site that is only HTML

1. `curl` the search page; there is no API and no feed.
2. Open the page source, find the row markers and the magnet links.
3. Copy `templates/guest-indexer`, fill the three `TODO`s, copy `templates/plugin-code-indexer.json`, set the host and the module name.
4. `scripts/build-plugin.sh`, then `scripts/try-module.sh` against the real site until the rows are right.
5. Hand back `<id>.json` and the `.wasm`, with the install steps. It is desktop-only.

### E. A debrid service

Follow section 8 with `templates/guest-service` (TorBox) as the model.

## 11. Pitfalls

- **A request that needs `{imdb}` is not made for a title with no IMDb id** (most anime). Use `{imdb_or_term}`, or add a second indexer that searches by name.
- **`rows` points at an object, not a list.** Use `*` (`torrents.*`) or the engine reads nothing.
- **Hash missing or in the wrong case or format.** Case does not matter; 40 hex or 32 base32 does. The row is dropped otherwise.
- **Forgetting `empty_when`.** A successful empty answer that leaves the list out looks like a bad answer and the indexer is marked as failing.
- **A provider `url` that does not start with `{base}/`.** Refused.
- **Plugins with a private or http address, a port, or a redirect.** Refused or fails.
- **Wrong genre spelling.** Use the provider's own words in `screens.genres`.
- **Forgetting the credits.** `screens.about` must name every catalogue and subtitle source.
- **Forgetting to raise `version`.** Nothing changes for users.
- **Putting a key in `sources.json`.** Never.
- **Publishing without being asked.** Never.
- **Trusting `check`.** It cannot know if a site is alive or the paths are right. Run `try-local.sh` or `try-module.sh`.
- **A module that depends on the page layout** breaks when the site changes its HTML. Say so.
- **The first release of a code plugin or service is only tested against what you could reach.** Say what you could not test (a key you do not have, a site that was down).

## 12. The final report

Finish with plain words:

- **What you built:** which source, of which kind, for whom (`sources.json` or a plugin), and the file names.
- **What you tested:** the checker, the `jq` path checks, `try-local.sh` (which titles, how many releases from the new source) or `try-module.sh` (how many rows), the fixture test.
- **What you could not verify,** and why (the site was down, you had no key, a protection stopped you).
- **How to install or publish it:** the exact commands.
- **What to watch:** a site that changes its markup, mirrors that die, keys stored in plain text.
- **Whether it is published:** normally "no, not until you say".
