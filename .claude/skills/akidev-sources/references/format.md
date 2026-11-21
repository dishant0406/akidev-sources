# The format of sources.json, field by field

Everything here is read from the code in `<code repo>/desktop/core/src/` (`definition.rs`, `sources.rs`, `screens.rs`). When this file and the code disagree, the code is right: read it and fix this file.

## Contents

1. The document
2. Reading values: paths, expressions, conditions, templates
3. Indexers
4. Providers
5. Chains
6. Mappers
7. Subtitle sources
8. Screens
9. Whole-file rules the checker enforces

---

## 1. The document

```json
{
  "schema": 1,
  "version": 43,
  "min_version": "0.1.17",
  "min_version_message": "Please update.",
  "trackers": ["udp://tracker.opentrackr.org:1337/announce"],
  "indexers": [],
  "providers": [],
  "mappers": [],
  "subtitles": [],
  "chains": { "anime": ["anilist"], "series": ["cinemeta", "tvmaze"], "movie": ["cinemeta", "yts"] },
  "screens": {}
}
```

| Key | Needed | Meaning and limits |
| --- | --- | --- |
| `schema` | yes | Format number. 1 for the document everyone reads. An app refuses a higher one than it knows. |
| `version` | yes | Content version. Must beat the one in use. At most 2^40. |
| `min_version` | no | `major.minor.patch`. Apps older than this show an update screen only. A malformed value makes the whole document invalid (so a typo can never lock anyone out). |
| `min_version_message` | no | Up to 300 characters, shown on that screen. |
| `trackers` | yes | At most 32. Added to every magnet. The daily job overwrites them in the live copy. |
| `indexers` | yes | 1 to 64. |
| `providers` | yes | 1 to 64. |
| `mappers` | no | At most 8. |
| `subtitles` | no | At most 16. |
| `chains` | yes | Providers per kind, in order. |
| `screens` | no | Missing means the built-in screens are used. |

Never in a signed document: `code` on an indexer or provider, `services`. Those are plugin-only and make the document refused. The whole document is at most 1 MiB.

---

## 2. Reading values

### Paths

- Dotted keys: `data.movies`.
- A number is a list position: `videos.0.id`.
- `*` is every value of an object or list: `torrents.*.hash`.
- A key met in a list is read in each element.
- A list found at the end of a path is read element by element.
- `""` is the whole body.
- In a nested row (indexer `children`), `^.` reads the row around: `^.title`.

### Expressions (anywhere a field wants a value)

| Form | Meaning |
| --- | --- |
| `"a.b"` | A path. |
| `["a", "b"]` | Several expressions, values gathered. |
| `{"template": "{^.title}{? ({^.year})?}"}` | Text with `{path}` holes. `{^.path}` is the row around. `{@kind}` is the kind. `{? ... ?}` vanishes when a hole inside is empty. An empty hole outside a group empties the value. |
| `{"const": "text"}` | Fixed text. |
| `{"by_kind": {"anime": "a", "movie": "b"}}` | The expression for the kind searched. |
| `{"regex": {"from": EXPR, "pattern": "..."}}` | First capture group. |
| `{"line": {"from": EXPR, "skip": "regex", "index": 0}}` | One line of multi-line text, skipping lines that match `skip` (`skip` optional). |
| `{"coalesce": [EXPR, ...]}` | First that has a value. |
| `{"join": [EXPR, ...]}` | Parts, space separated, leaving out a part another contains. |
| `{"magnet_hash": EXPR}`, `{"magnet_name": EXPR}`, `{"magnet_size": EXPR}` | What a magnet link carries. |
| `{"year": EXPR}` | First four digits ("2008–2013" is 2008). |
| `{"minutes": EXPR}` | First number ("143 min" is 143). |
| `{"scale": {"from": EXPR, "by": 10}}` | Number times `by`, rounded. |
| `{"add": {"from": EXPR, "n": 1}}` | Number plus `n`. |
| `{"positive": EXPR}` | The number when above zero, otherwise nothing. |
| `{"map": {"from": EXPR, "table": [["needle", "value"]]}}` | Value for the first needle the lowercased text contains. |
| `{"plain_text": EXPR}` | HTML to text: line breaks kept, tags removed, entities decoded. |

Regexes are Rust `regex` syntax and are compiled at check time, so a bad pattern makes the document invalid.

### Conditions

Used by `drop`, `empty_when` and `missing`. All the tests named in one condition must hold.

```json
{ "path": "categoryId", "starts_with": "5" }
```

| Field | Meaning |
| --- | --- |
| `path` | Expression tested. A list at the path matches if any element does. |
| `equals`, `starts_with` | Text tests. |
| `differs` | Nothing at the path is this (a path leading to nothing counts). |
| `exists` | `true` or `false`: the path leads to something (not null). |
| `after_today` | `{"grace_days": N}`: the date or year is later than today plus N days. |
| `outside_recent_years` | `{"behind": N, "grace_days": N}`: the year is not this year or the N before it. |
| `when` | Counts only while this is being asked: `genre`, `year` or `sort:<name>`. |

Day and year numbers: 0 to 3650.

### Templates in requests

- `{name}` hole. `{? ... ?}` group left out when a hole inside is empty.
- In JSON bodies: `{"$kind": {...}}`, `{"$sort": {...}}`, `{"$number": "{page}"}`, `{"$text": "..."}` (text left exactly as is, for GraphQL), and keys ending in `?` left out when empty.

---

## 3. Indexers

```json
{
  "id": "nyaa",
  "name": "Nyaa",
  "kinds": ["anime"],
  "hosts": ["https://nyaa.si", "https://nyaa.land"],
  "cooldown_secs": 60,
  "fanout": "per-term",
  "map": "kitsu",
  "fallback": false,
  "server_only": false,
  "request": { "method": "GET", "path": "/", "query": { "q": "{term}" }, "json": null, "headers": {} },
  "response": { "format": "rss", "fields": { "title": "title", "hash": "nyaa:infoHash" } }
}
```

| Field | Needed | Meaning |
| --- | --- | --- |
| `id` | yes | Unique. Shown as the release's source. |
| `name` | yes | Shown in Settings. |
| `kinds` | yes | Kinds served. Not empty. |
| `hosts` | yes | 1 to 8 mirrors of one service, in order. Each starts `http://` or `https://`. |
| `cooldown_secs` | no | Rest after a failure. Default 60, at most 3600. |
| `fanout` | no | `per-term` (default), `per-title`, `once`. |
| `map` | no | A mapper id. The mapper must exist and map one of the indexer's kinds. |
| `fallback` | no | `true`: last resort, asked only when the others found nothing worth opening, with longer to answer. |
| `server_only` | no | `true`: only the server asks it; the desktop app skips it. |
| `request` | yes | See below. |
| `response` | yes | See below. |
| `code` | plugin only | An export of the plugin's module that makes the requests. |

### request

| Field | Meaning |
| --- | --- |
| `method` | `GET` (default) or `POST`. |
| `path` | Added after the host. String or `{"$kind": {...}}`. |
| `query` | Map of query values (holes allowed). |
| `json` | Body for `POST` (holes and `$` specials allowed). |
| `headers` | Sent with every request. Names and values must be valid HTTP. |

Holes: `{term}`, `{imdb}`, `{imdb_digits}`, `{imdb_or_term}`, `{season}`, `{episode}`, `{<mapper id>}`, `{<mapper id>_kind}`. A request needing a value the search lacks is not made.

### response

| Field | Meaning |
| --- | --- |
| `format` | `json` or `rss`. RSS: tag text under the tag name, attributes as `tag@attribute` (Torznab: `torznab:attr@seeders`); rows are the items, no `rows` path. |
| `rows` | Path to the rows. Empty means the body. |
| `children` | Rows nested in each row. Their fields reach the outer row with `^.`. |
| `fields` | See below. |
| `drop` | Conditions. A matching row is dropped. |
| `empty_when` | Conditions on the whole body. When all hold, a successful empty answer. |
| `must_contain_term` | Keep only rows whose title holds the whole searched title. |
| `dedupe` | `{"avoid": "regex"}`: one row per `(hash, file_idx)`, preferring a title that does not match `avoid`. |

### fields

| Field | Needed | Meaning |
| --- | --- | --- |
| `title` | yes | Release name. |
| `hash` | yes | 40-hex or 32-base32 info hash. Invalid means the row is dropped. |
| `magnet` | no | Used only if it is for this hash. Otherwise built from hash + trackers. |
| `size` | no | Bytes or `1.3 GB` style text. |
| `file_idx` | no | Zero-based file in the torrent. |
| `seeders` | no | Count. Missing or invalid stays unknown; a valid `0` is a real zero. Never invent a default 0. |

Stremio-shaped addons: use `behaviorHints.filename` and `behaviorHints.videoSize`, `fileIdx` for `file_idx`, and only `infoHash`. Never use an addon's direct-play URL.

---

## 4. Providers

```json
{
  "id": "tvmaze",
  "kinds": ["series"],
  "base_url": "https://api.tvmaze.com",
  "types": {},
  "sorts": { "default": "x" },
  "card": { "id": "id", "title": "name" },
  "list": { "request": { "url": "{base}/schedule/full" }, "rows": "_embedded.show", "paging": { "style": "pool" } },
  "search": { "request": { "url": "{base}/search/shows?q={term}" }, "rows": "show" },
  "detail": { "request": { "url": "{base}/shows/{id}" }, "root": "" },
  "image_hosts": ["tvmaze.com"]
}
```

| Part | Needed | Meaning |
| --- | --- | --- |
| `id` | yes | Unique. |
| `kinds` | yes | Kinds it has. |
| `base_url` | yes | `{base}`. `http(s)://`, no braces. |
| `types` | no | Kind to the service's word for it (`{type}`). |
| `sorts` | no | Sort to the service's word (`{sort}`). `default` covers unnamed sorts. |
| `card` | yes | How a title is read. |
| `list`, `search` | no | A page of titles; a search. |
| `detail` | yes | One title in full. |
| `image_hosts` | no | Up to 16 bare host names (match subdomains too). The image proxy fetches only from these, other providers' hosts, and the operator's `IMAGE_HOSTS`. |
| `code` | plugin only | Export of the plugin's module. |

Every request `url` must be `{base}` or start with `{base}/`. Provider holes: `{base}`, `{type}`, `{sort}`, `{id}`, `{term}`, `{page}`, `{per_page}`, `{skip}`, `{genre}`, `{genre_lower}`, `{year}` (each percent-encoded). A request may have `method`, `query`, `json`.

### card

`id` and `title` required. Optional: `title_variants`, `poster`, `banner`, `description`, `format`, `status`, `year`, `episodes`, `runtime_minutes`, `score` (out of 100, use `scale`), `popularity`, `genres`, `adult`.

### list

`request`, `rows`, `paging` required. Optional: `check`, `ttl_secs` (default 600, at most 86400), `dedupe` (expression), `drop`, `genre`, `year` (how a row names them, for filtering here), `order` (sort name or `default` to a list of `{by, compare, descending, missing_last}`; `compare` is `text`, `caseless` or `number`).

### paging

`per_page` (default 24, at most `max`), `max` (default 50, 1 to 200), then one style:

- `page`: `{"style": "page", "next": {"flag": "path"} | {"total": "path"}, "widen": {"when": ["genre"], "per_page": 100}}`. `widen` optional.
- `skip`: `{"style": "skip", "size": 25, "window": {"when": ["genre", "year"], "pages": 4}}`. `size` above 0; `ceil(max / size)` at most 4; `pages` 1 to 4.
- `pool`: `{"style": "pool"}`. One answer, paged here.

`when` entries: `genre`, `year` or `sort:<name>` only.

### search

`request`, `rows` required. Optional: `check`, `ttl_secs`, `drop`, `per_page`, `next`.

### detail

`request` required. Optional: `id_pattern` (regex of ids the service has), `check`, `root`, `missing` (conditions), `description`, `count_episodes`, `imdb_id`, `studios`, `trailer` (`{site, id}`), `episodes`, `cast`, `related`, `recommended`.

- `episodes`: `rows`, `id`, `season`, `number` required; `name`, `airdate`, `drop` optional.
- `cast`: `{"sources": [{"rows", "name", "role", "image"}], "limit": 12}`; first source with anyone wins.
- `related` and `recommended`: `{"request", "check", "rows", "drop", "limit"}`; with a `request` a failure leaves the list empty.

### check (how an arrived answer can still be an error)

```json
{ "error": "errors", "message": "errors.0.message", "ok": { "path": "status", "equals": "ok" } }
```

`error`: anything at this path means failure. `ok`: a condition the answer must satisfy. `message`: where the reason is.

---

## 5. Chains

```json
{ "anime": ["anilist"], "series": ["cinemeta", "tvmaze"], "movie": ["cinemeta", "yts"] }
```

The first provider answers; the next answers when it returns nothing or fails. Each built-in kind: 1 to 8 providers, no repeats, each must exist and serve the kind. Plugin catalogues are not in chains.

---

## 6. Mappers

```json
{ "id": "kitsu", "kinds": ["anime"], "provider": { "id": "anime-kitsu", "kinds": ["anime"], "base_url": "https://anime-kitsu.strem.fun", "card": { "id": "kitsu_id", "title": "name" }, "detail": { "request": { "url": "{base}/meta/anime/anilist:{id}.json" }, "id_pattern": "^[0-9]+$", "root": "meta", "episodes": { "rows": "videos", "id": "id", "season": "season", "number": "episode" } } } }
```

- `id`: lower case letters only; not `term`, `imdb`, `imdb_digits`, `imdb_or_term`, `season`, `episode`.
- It names the holes `{id}` and `{id_kind}` and the front of the ids `id:<title>:<episode>` (or `id:<title>` for a film).
- The provider is asked by our own id (AniList's, digits). Only an exact same-number episode counts. Anything else is no mapping and the indexer is skipped.
- An indexer opts in with `"map": "<id>"`.

---

## 7. Subtitle sources

| Field | Needed | Meaning |
| --- | --- | --- |
| `id`, `name` | yes | Shown as where a subtitle came from. |
| `kinds` | yes | Kinds served. |
| `hosts` | yes | 1 to 8 mirrors. |
| `cooldown_secs` | no | Default 60, at most 3600. |
| `file_hosts` | yes | 1 to 16 bare host names. Files are fetched only from these (and subdomains). |
| `lookup` | no | `{kinds, url, rows, value, max_episodes, skip_title}`: finds an IMDb id for a title without one. `url` has `{term}`. Skipped for titles with more than `max_episodes` episodes or matching `skip_title`. |
| `request` | yes | Like an indexer's. Holes: `{imdb}`, `{season}`, `{episode}`, `{term}`, `{year}`. |
| `response` | yes | `rows`, `fields`, optional `drop`. |

Fields: `id`, `url`, `lang` (2 or 3 letters) required; `label`, `format` (`srt`, `ass`, `vtt`; read from the file if absent), `hearing_impaired` optional. A subtitle is converted to WebVTT.

---

## 8. Screens

```json
{
  "tabs": [{ "kind": "anime", "slug": "anime", "label": "Anime", "tag": "ANIME" }],
  "sorts": [{ "sort": "popularity", "label": "Popular" }],
  "genres": { "anime": ["Action"], "all": [] },
  "home": [{ "title": "Trending Anime", "kind": "anime", "sort": "trending", "genre": "Action", "provider": "anilist" }],
  "about": { "attribution": "Metadata from AniList (CC BY-SA).", "catalogues": ["AniList"], "subtitles": ["OpenSubtitles"] }
}
```

- `tabs`: 1 to 16. `slug` lower case letters and dashes, not `search`, `title`, `watch`, `download`, `privacy`, `manga`, `info`. `tag` and `label` not empty. Slug, kind and label unique.
- `sorts`: 1 to 16. The first is the default. Known sorts: `popularity`, `trending`, `score`, `recent`, `title`.
- `genres`: key is `all` or a real kind; up to 64 each. Use each provider's own spelling.
- `home`: 1 to 32 rows. A row's `kind` must have a tab. `provider` (optional) must exist and serve the kind. `genre` optional.
- `about`: `attribution` 1 to 1000 characters; `catalogues` and `subtitles` up to 32 names each, 1 to 64 characters per name.

---

## 9. Whole-file rules the checker enforces

- Unique ids among indexers, among providers, among mappers, among subtitle sources.
- Every indexer: at least one kind, 1 to 8 hosts, a fillable request for every kind it serves, valid regexes, valid header names and values.
- Every provider: `base_url` without braces, every request starting at `{base}`, valid regexes, page sizes in range.
- An indexer's `map` names a mapper that exists and maps one of its kinds.
- Chains: each built-in kind has 1 to 8 distinct providers that exist and serve it.
- `min_version` is `major.minor.patch` if present.
- Screens pass their own checks, and home rows that name a provider name one that serves the kind.
- The document is at most 1 MiB and has no `code` or `services`.
