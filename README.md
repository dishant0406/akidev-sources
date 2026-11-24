# Akidev sources

This repository contains `sources.json`, this README, optional plugins, and research tools. It is the list of everywhere Akidev looks for stuff: which catalogues have the titles, which torrent sites have the releases, which sites have the subtitles, and what the screens look like.

The point of it: you can add a source, move one, or remove one **without building or shipping a new app**. You edit this file, publish it, and every running app and the server picks it up.

Nothing in the file is code. It only says "make this request, read these fields". The code that follows the instructions lives in the other repo, [dishant0406/akidev](https://github.com/dishant0406/akidev), in `desktop/core/`.

## Read this first: how the two repos fit

- This repository holds the data, plugin modules, and verification tools. It contains no secrets.
- **The code repo (akidev)** reads the data, checks it, signs it and publishes it. In the commands below, `<code repo>` means a checkout of that repo, and `SOURCES_DIR` means a checkout of this one.
- Every build of the app and the server has a copy of `sources.json` inside it. `desktop/core/build.rs` downloads it from this repo's `main` branch when `desktop/sources/sources.json` is missing. So a build needs the network once.
- Running apps also download newer copies from `sources.akidev.live`, in the background.

## Contents

1. [Words you need](#words-you-need)
2. [How the file travels](#how-the-file-travels)
3. [Change something and ship it](#change-something-and-ship-it)
4. [The file from top to bottom](#the-file-from-top-to-bottom)
5. [Reading values: paths, expressions, conditions, templates](#reading-values)
6. [Indexers (torrent sites)](#indexers)
7. [Providers (catalogues)](#providers)
8. [Chains](#chains)
9. [Mappers](#mappers)
10. [Subtitles](#subtitles)
11. [Screens](#screens)
12. [Plugins](#plugins)
13. [Recipes](#recipes)
14. [Let an agent write a source for you](#let-an-agent-write-a-source-for-you)
15. [Troubleshooting](#troubleshooting)
16. [What the file cannot do](#what-the-file-cannot-do)
17. [All the limits in one place](#all-the-limits-in-one-place)

---

## Words you need

- **Kind**: what sort of title it is. The built-in kinds are `anime`, `series` and `movie`. A plugin can add more.
- **Shape**: how a kind behaves. `anime` has episodes by number. `series` has seasons and episodes. `movie` has no episodes. Every kind has one of these three shapes. The shapes are engine code, not data.
- **Indexer**: a torrent site (or an addon that lists torrents). You ask it a question, it answers with a list of releases.
- **Release**: one torrent for a title: a name, an info hash, a size, a seeder count.
- **Provider** (also called a **catalogue**): a site that knows what titles exist: AniList, Cinemeta, TVMaze, YTS. It gives you lists, search results, and the page of one title.
- **Chain**: for each kind, the providers in order. The first one answers. If it comes back empty or fails, the next one answers.
- **Mapper**: turns one catalogue's id for a title into another service's id. The built-in one turns an AniList id into a Kitsu id.
- **Subtitle source**: a site that has subtitle files for an episode or a film.
- **Screens**: the tabs, sorts, genres, home rows, labels and credits that both the website and the desktop app draw.
- **Tracker**: a public torrent tracker. A few are added to every magnet link.
- **Hole**: a `{name}` in a request that gets filled in, like `{term}` or `{season}`.
- **Row**: one item in an answer (one release, one title).
- **Field**: one value you read out of a row (the title, the hash).
- **Expression**: the recipe for reading a field. Usually just a path like `data.title`, sometimes something fancier.
- **Plugin**: an extra JSON file (plus an optional `.wasm` file) that a user adds to the desktop app, to bring sources of their own.
- **Schema**: the version of the file *format*. **Version**: the version of the file's *content*.

---

## How the file travels

Here is the whole trip, from your edit to a user's screen.

1. You edit `sources.json` here and raise `version`.
2. You run `publish-sources.sh` from the code repo. It checks the file, checks that old apps would accept it, signs it with a private key, and uploads it to a Cloudflare R2 bucket.
3. The bucket is shown at `sources.akidev.live`. The file is published **twice**, with one version number:
   - the root (`sources.akidev.live/sources.json`), schema 1, which every app reads
   - `/v2` (`sources.akidev.live/v2/sources.json`), the same document with `"schema": 2`, which only newer builds read, and prefer
4. Every app and the server asks for a new copy at start and about every 6 hours.
5. A downloaded copy is used **only** if:
   - its signature is valid (checked with the public key that is baked into the code),
   - its `version` is higher than the one in use (the same version with a higher schema also wins),
   - and it passes the same checks as the built-in copy.
6. If any of that fails, the app keeps what it has. A bad publish is undone by publishing a corrected copy with a higher `version`.

Why two feeds? An app that only knows schema 1 refuses a whole document that says `"schema": 2`. So a value that only newer apps can read goes in `sources-v2.json` (put it next to `sources.json` in this repo), which gets published as `/v2`. Its `version` must equal `sources.json`'s. Until you need that, the two feeds are the same document.

### Where the website, the server and the desktop app use it

- **The server** reads it for catalogues, torrent sites, subtitles, screens and trackers. It sends the screens to the website at `GET /v1/screens`.
- **The website** reads only the screens (through the server). Tabs, sorts, genres, home rows, the label over a title, the footer credit and the privacy page's source names all come from there.
- **The desktop app** reads everything, because it runs the same engine on the user's own computer. Plugins are merged on top of it.

---

## Change something and ship it

1. Edit `sources.json` and **raise `version`**. Every publish must be higher than the live one.
2. Test it. Copy your edit to `<code repo>/desktop/sources/sources.json` (the build only downloads when that file is missing), then run these in `<code repo>/desktop`:

   ```bash
   cargo run -p akidev-core --bin akidev-sources -- check "$SOURCES_DIR/sources.json"
   cargo test -p akidev-core
   ```

   The first command validates the file on its own. The tests check that the file parses and that each indexer reads a sample answer correctly.
3. **Test against the real service too.** The checks cannot know if a mirror is alive, or if a GraphQL query is right. Try the real request first.
4. Publish:

   ```bash
   SOURCES_DIR=<this checkout> ./scripts/publish-sources.sh
   ```

   Running apps pick it up within about 6 hours. Anyone who opens the app after that gets it at start.

   To tell the old-app check which release is the oldest one you still support, set `OLD_REF`:

   ```bash
   OLD_REF=desktop-mac-v0.1.27 SOURCES_DIR=<this checkout> ./scripts/publish-sources.sh
   ```

The publish script refuses a file that is not newer than what is live. It also builds the schema 2 copy, signs both, and uploads `/v2` first and the root second.

### Order matters when you add a new field

If the file uses a new field that only a newer server or app understands, **publish the file first, then ship the server or the app**. The other way round, the new code runs without the data it needs. Old apps ignore fields they do not know. They refuse a whole document that has a *value* they do not know (a new hole name, a new kind, a higher schema).

### The daily tracker job

`.github/workflows/refresh-trackers.yml` (in the code repo) runs every day.

- It downloads the document that is live at `sources.akidev.live`.
- It runs `scripts/refresh-trackers.sh` on it: the first 32 `udp` and `http(s)` trackers of [ngosang/trackerslist](https://github.com/ngosang/trackerslist) (`trackers_all.txt`, best first) go into `trackers`, and `version` goes up.
- It signs the result and publishes it.
- It never touches this repo. So the **live** document is the one that counts, and `sources.json` here is just the built-in copy. A hand edit of `trackers` is overwritten by the next run.

It needs these repository secrets in the code repo: `SOURCES_SIGNING_KEY` (the contents of `.secrets/sources.key`), `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`.

### Forcing old apps to update

Two optional fields at the top of the document lock out apps that are too old:

```json
{
  "min_version": "0.1.17",
  "min_version_message": "This version has a bug that breaks parties. Please update."
}
```

- An app whose version is lower than `min_version` shows an "Update required" screen (with the message, an Update button and the download page) and nothing else.
- It does that as soon as it reads the document: from its saved copy at start, and again when the background check picks up a newer one.
- Newer apps, and apps from before this field existed, run as normal.
- A `min_version` that is not `major.minor.patch` makes the **whole document invalid**, so a typo can never lock anyone out (the previous document stays in use).
- `min_version_message` can be up to 300 characters.
- Publish the release that the version points to **first**. The Update button finds it from the release feed.
- To lift the lock, publish a document without the field (or with a lower one) and a higher `version`.

### One-time setup (already done, here for the record)

- An R2 bucket with the custom domain `sources.akidev.live`, made with the `cf` CLI:

  ```bash
  cf r2 buckets create-by-name akidev-sources
  cf r2 buckets domains custom create akidev-sources --domain sources.akidev.live --zone-id <zone> --min-tls 1.2 --enabled
  ```

- The signing key:

  ```bash
  cargo run -p akidev-core --bin akidev-sources -- keygen .secrets/sources.key
  ```

  It prints the public half. That public half is `PUBLIC_KEY` in `core/src/sources.rs`. The private file is git-ignored. Keep a copy in a password manager. Losing it means shipping a build with a new public key.

---

## The file from top to bottom

This is the shape of `sources.json`. It is shortened here (the real file has many more entries) and the `[]` and `{}` are placeholders.

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
  "chains": {
    "anime": ["anilist"],
    "series": ["cinemeta", "tvmaze"],
    "movie": ["cinemeta", "yts"]
  },
  "screens": {}
}
```

| Key | Needed? | What it is |
| --- | --- | --- |
| `schema` | yes | The format number. An app refuses a document with a higher one than it knows. Use `1`. |
| `version` | yes | The content version. Must go up with every publish. At most 2^40. |
| `min_version`, `min_version_message` | no | Lock out apps that are too old. See above. |
| `trackers` | yes | Public trackers added to every magnet. At most 32. |
| `indexers` | yes | The torrent sites. 1 to 64. |
| `providers` | yes | The catalogues. 1 to 64. |
| `mappers` | no | Id mappers. At most 8. |
| `subtitles` | no | Subtitle sources. At most 16. |
| `chains` | yes | Which providers answer for each kind, in order. |
| `screens` | no | The tabs, sorts, genres, home rows and credits. When it is missing, the built-in screens are used. |

Two things a signed document can **never** contain: a `code` field (WebAssembly) and `services` (stream services). Those are plugin-only. A document that has one is refused. A document over 1 MiB is refused too.

A few rules the checker enforces for the whole file:

- Every indexer, provider, mapper and subtitle source has a **unique id**.
- Each of the three built-in kinds has a chain of 1 to 8 providers. No provider appears twice in one chain. Every provider named must exist and must serve that kind.
- An indexer that names a mapper must name one that exists and maps at least one of the indexer's kinds.
- A home row that names a provider must name one that serves the row's kind.

---

## Reading values

Indexers, providers and subtitle sources all read values out of answers the same way. Learn this once and the rest is easy.

### Paths

A path is a dotted list of keys: `data.movies`. Some details:

- A number in a path is a position in a list: `videos.0.id`.
- `*` means every value of an object or list: `torrents.*.hash`.
- A key met in a list is read in **each** element of the list.
- A list found at the end of a path is read element by element.
- An empty path (`""`) means the whole body.
- Inside a nested row (see `children`), `^.` at the front reads the row **around** this one: `^.title`.

### Expressions

Wherever a field wants a value, you give an **expression**. It is one of these:

| Form | Example | What it does |
| --- | --- | --- |
| a string | `"data.title"` | Read that path. |
| a list | `["a", "b"]` | Read several and gather the values. |
| `template` | `{"template": "{^.title}{? ({^.year})?}"}` | Text with `{path}` holes. `{^.path}` reads the row around. `{@kind}` is the kind. `{? ... ?}` vanishes when a hole inside is empty. A hole outside a group that is empty empties the whole value. |
| `const` | `{"const": "srt"}` | A fixed text. |
| `by_kind` | `{"by_kind": {"anime": "a.b", "movie": "c.d"}}` | The expression for the kind being searched. |
| `regex` | `{"regex": {"from": "title", "pattern": "([0-9]+)"}}` | The first capture group. |
| `line` | `{"line": {"from": "title", "skip": "👤", "index": 0}}` | One line of a multi-line text, skipping lines that match `skip`. |
| `coalesce` | `{"coalesce": ["a", "b"]}` | The first one that has a value. |
| `join` | `{"join": ["a", "b"]}` | The parts, space separated, leaving out a part that another contains. |
| `magnet_hash`, `magnet_name`, `magnet_size` | `{"magnet_hash": "link"}` | What a magnet link carries: its info hash, its display name, its size in bytes. |
| `year` | `{"year": "premiered"}` | The first four digits in a text ("2008–2013" is 2008). |
| `minutes` | `{"minutes": "runtime"}` | The first number in a text ("143 min" is 143). |
| `scale` | `{"scale": {"from": "rating.average", "by": 10}}` | A number times `by`, rounded (a rating out of 10 as a score out of 100). |
| `add` | `{"add": {"from": "n", "n": 1}}` | A number plus `n`. |
| `positive` | `{"positive": "count"}` | The number when it is above zero, otherwise nothing. |
| `map` | `{"map": {"from": "format", "table": [["tv", "TV"], ["movie", "Film"]]}}` | The value for the first needle that the lowercased text contains. |
| `plain_text` | `{"plain_text": "summary"}` | HTML as plain text: line breaks kept, tags removed, entities decoded. |

Regular expressions use Rust's `regex` syntax. A bad pattern makes the document invalid, so it is caught before it is installed.

### Conditions

A condition tests a row. It is used by `drop` (leave the row out), `empty_when` (the answer has no rows) and `missing` (the title does not exist). All the tests a condition names must hold for it to match.

```json
{ "path": "categoryId", "starts_with": "5" }
```

| Field | Meaning |
| --- | --- |
| `path` | What is tested. When it reaches a list, any element may match. |
| `equals` | The value is exactly this text. |
| `starts_with` | The value starts with this text. |
| `differs` | Nothing at the path is this. A path that leads to nothing counts. |
| `exists` | `true` or `false`: whether the path leads to something (not null) at all. |
| `after_today` | `{"grace_days": 30}`: the date or year found is later than today plus a few days, so it is not out yet. |
| `outside_recent_years` | `{"behind": 2, "grace_days": 30}`: the year found is not this year or the `behind` years before it. |
| `when` | The condition only counts while this holds: `genre` or `year` is being asked for, or `sort:<name>` is the sort. |

Numbers of days and years must be between 0 and 3650.

### Templates and holes in requests

In a request (a path, a query value, a JSON body, a URL) a `{name}` is a **hole** that gets filled in.

- `{? ... ?}` is a group that is left out when a hole inside it is empty.
- In a JSON body, these special objects work:
  - `{"$kind": {"anime": ..., "movie": ...}}` is replaced by the entry for the kind being searched.
  - `{"$sort": {"recent": ...}}` picks by the sort asked for.
  - `{"$number": "{page}"}` fills a text and reads it as a number.
  - `{"$text": "..."}` is a text left exactly as it is. Use it for a GraphQL query, which is full of braces.
  - A key that ends in `?` (`"genre?"`) is left out when its value is empty.
- Which holes exist depends on what you are writing (see each section).

---

## Indexers

An indexer is one torrent site. Here is a small real one, Nyaa, which answers with an RSS feed:

```json
{
  "id": "nyaa",
  "name": "Nyaa",
  "kinds": ["anime"],
  "hosts": ["https://nyaa.si", "https://nyaa.land", "https://nyaa.iss.ink", "https://nyaa.net"],
  "request": {
    "path": "/",
    "query": {
      "page": "rss",
      "q": "{term}",
      "c": "1_0",
      "f": "0"
    }
  },
  "response": {
    "format": "rss",
    "fields": {
      "title": "title",
      "hash": "nyaa:infoHash",
      "size": "nyaa:size",
      "seeders": "nyaa:seeders"
    }
  }
}
```

### Every field of an indexer

| Field | Needed? | What it does |
| --- | --- | --- |
| `id` | yes | A unique id. Shown as where a release came from. |
| `name` | yes | The name a viewer sees in Settings. |
| `kinds` | yes | The kinds it serves (`anime`, `series`, `movie`, or a plugin's). |
| `hosts` | yes | 1 to 8 mirrors of the same service. Tried in order. Every one must start with `http://` or `https://`. |
| `cooldown_secs` | no | How long a host that failed rests. Default 60. At most 3600. |
| `min_interval_secs` | no | Minimum space between indexer requests on this service host. Default 0. At most 3600. |
| `max_requests_per_day` | no | Indexer-request limit for one UTC day in the current process. IDs on the same host share it. A code module call consumes one unit. |
| `fanout` | no | `per-term` (default), `per-title` or `once`. See below. |
| `request` | yes | What to ask. See below. |
| `response` | yes | How to read the answer. See below. |
| `map` | no | The id of a mapper. See [Mappers](#mappers). |
| `fallback` | no | `true` makes it a last resort. |
| `server_only` | no | `true` means only the server asks it. |

**`fanout`** decides how many requests one search makes:

- `per-term`: once for each search term (a title, its other names, with and without an episode number).
- `per-title`: once for each distinct title. Use it for an index that answers with every episode of a show, or that has no episode syntax, so asking per episode form would fetch the same thing again and again.
- `once`: a single time. The term plays no part (an IMDb id does).

**`hosts`** are mirrors of one service, not different services. A host that fails rests for `cooldown_secs`, so a dead mirror is not asked again for every search term. The next mirror is tried after a failure, and also after a short delay if the first one is slow.

**`fallback: true`** makes the indexer a last resort. It is asked only when the others found nothing worth opening, and it gets longer to answer (the `fallback_timeout_ms` setting). Use it for a slow service that should not be paid for on every search. The `prowlarr` entry uses it.

**`server_only: true`** means only the server that serves the website asks this indexer. The desktop app skips it, so the app never calls your server for it. The `prowlarr` entry uses it, because it needs the server's own key.

### The request

```json
{
  "method": "POST",
  "path": "/search",
  "query": { "q": "{term}" },
  "json": { "query": "{term}" },
  "headers": { "x-api-key": "abc" }
}
```

- `method` is `GET` (default) or `POST`.
- `path` is added after the host. It is a string, or `{"$kind": {...}}` to differ per kind.
- `query` is a map of query-string values.
- `json` is a body, for `POST`.
- `headers` are sent with every request, for a service that wants a key or a marker in a header.

**Holes you can use** in `path`, `query` and `json`:

| Hole | Filled with |
| --- | --- |
| `{term}` | The search term. |
| `{imdb}` | The IMDb id, like `tt0903747`. |
| `{imdb_digits}` | The digits only, like `0903747`. |
| `{imdb_or_term}` | The IMDb id when the search has one, otherwise the term. |
| `{season}`, `{episode}` | The season and episode numbers. |
| `{<mapper id>}`, `{<mapper id>_kind}` | The mapped id, for an indexer with `map` (for the mapper `kitsu`: `{kitsu}` and `{kitsu_kind}`). |

A request that needs a value the search does not have (an IMDb id, for a title that has none) is **not made**.

### The response

```json
{
  "format": "json",
  "rows": "data.movies",
  "children": "torrents",
  "fields": { "title": "title", "hash": "hash" },
  "drop": [],
  "empty_when": [],
  "must_contain_term": false,
  "dedupe": { "avoid": "(?i)bonus" }
}
```

- `format` is `json` or `rss`.
  - In an RSS feed a tag's text is read under the tag's name, and its attributes under `tag@attribute`. A Torznab attribute (`<torznab:attr name="seeders" value="12"/>`) is `torznab:attr@seeders`, so any Torznab feed can be read. An RSS feed has no `rows` path: its rows are its items.
- `rows` is a path to the rows. `*` means every value of an object. A list found there is read element by element. Empty means the body itself.
- `children` reads rows nested inside each row (the torrents of a film). Their fields reach the outer row with `^.`.
- `fields` says how to read each value (see below).
- `drop` removes rows (a list of [conditions](#conditions)).
- `empty_when` is a list of conditions that read the **whole body**. When every one holds, the answer is a *successful* answer with no rows. Use it for a service that leaves the list out when nothing was found, which would otherwise look like a bad answer. YTS says it like this:

  ```json
  [
    { "path": "status", "equals": "ok" },
    { "path": "data.movie_count", "equals": "0" },
    { "path": "data.movies", "exists": false }
  ]
  ```

- `must_contain_term: true` keeps only rows whose title holds the whole searched title. Use it for an index with no category to filter on.
- `dedupe` keeps one row per `(hash, file_idx)`. `avoid` is a pattern: when several rows share a hash, the first whose title does **not** match is kept. It stops a bonus clip from standing for the season pack it was listed with.

### The fields

| Field | Needed? | What it is |
| --- | --- | --- |
| `title` | yes | The release name. |
| `hash` | yes | A 40 character hex or 32 character base32 info hash. A row without a valid one is dropped. |
| `magnet` | no | A magnet link. It is used only if it is for this very hash. Otherwise a magnet is built from the hash and the trackers. Most indexers send none, so you can leave it out. |
| `size` | no | Bytes, or text like `1.3 GB`. |
| `file_idx` | no | The zero-based file in the torrent, for an indexer that points at one file in a pack. |
| `seeders` | no | The seeder count. |

Each is an [expression](#expressions).

About `seeders`: it is optional observation data. Missing, malformed, negative, fractional or out-of-range values stay unknown (`null` in the API's output). A valid `0` stays an observed zero. **Do not** set a default zero for a provider that leaves health out. The count is what the upstream site said, not something Akidev measured.

### Real example: a JSON GET (Knaben)

```json
{
  "id": "knaben",
  "name": "Knaben",
  "kinds": ["anime", "series", "movie"],
  "hosts": ["https://api.knaben.org/v2"],
  "min_interval_secs": 2,
  "request": {
    "path": "/search",
    "query": {
      "q": "{term}",
      "sf": "title",
      "c": {
        "$kind": {
          "anime": "6000000",
          "series": "2000000",
          "movie": "3000000,2000000"
        }
      },
      "o": "seeders",
      "d": "desc",
      "s": "50",
      "f": "0"
    }
  },
  "response": {
    "format": "json",
    "rows": "hits",
    "drop": [{ "path": "categoryId", "starts_with": "5" }],
    "fields": {
      "title": "title",
      "hash": "hash",
      "size": "bytes",
      "seeders": "seeders"
    }
  }
}
```

### Real example: nested rows and "empty is fine" (YTS)

```json
{
  "id": "yts",
  "name": "YTS",
  "kinds": ["movie"],
  "hosts": [
    "https://movies-api.accel.li/api/v2",
    "https://yts.gg/api/v2"
  ],
  "request": {
    "path": "/list_movies.json",
    "query": {
      "query_term": "{imdb_or_term}",
      "limit": "50"
    }
  },
  "response": {
    "format": "json",
    "rows": "data.movies",
    "children": "torrents",
    "empty_when": [
      { "path": "status", "equals": "ok" },
      { "path": "data.movie_count", "equals": "0" },
      { "path": "data.movies", "exists": false }
    ],
    "fields": {
      "title": {
        "template": "{^.title}{? ({^.year})?}{? {quality}?}{? {type}?}"
      },
      "hash": "hash",
      "size": "size_bytes",
      "seeders": "seeds"
    }
  }
}
```

### Real example: a Stremio addon, asked by an id (Torrentio)

Torrentio is asked by IMDb id (and for anime by a mapped Kitsu id), with the season and episode in the path. Its answers hold the description in either `title` or `description`, so the title is built from lines of it.

```json
{
  "id": "torrentio",
  "name": "Torrentio (IMDb and mapped Anime Kitsu)",
  "map": "kitsu",
  "kinds": ["anime", "series", "movie"],
  "fanout": "once",
  "hosts": ["https://torrentio.strem.fun"],
  "request": {
    "path": {
      "$kind": {
        "movie": "/stream/movie/{imdb}.json",
        "series": "/stream/series/{imdb}:{season}:{episode}.json",
        "anime": "/stream/{kitsu_kind}/{kitsu}.json"
      }
    }
  },
  "response": {
    "format": "json",
    "rows": "streams",
    "dedupe": {
      "avoid": "(?i)(?:^|[^a-z0-9])(?:bonus|discarded|deleted|behind[ ._]*the[ ._]*scenes|bloopers?|outtakes?)(?:[^a-z0-9]|$)"
    },
    "fields": {
      "title": {
        "join": [
          {
            "line": {
              "from": { "coalesce": ["title", "description"] },
              "skip": "👤|💾",
              "index": 0
            }
          },
          {
            "coalesce": [
              "behaviorHints.filename",
              {
                "line": {
                  "from": { "coalesce": ["title", "description"] },
                  "skip": "👤|💾",
                  "index": 1
                }
              },
              {
                "line": {
                  "from": { "coalesce": ["title", "description"] },
                  "skip": "👤|💾",
                  "index": 0
                }
              }
            ]
          }
        ]
      },
      "hash": "infoHash",
      "file_idx": "fileIdx",
      "size": {
        "coalesce": [
          "behaviorHints.videoSize",
          {
            "regex": {
              "from": { "coalesce": ["title", "description"] },
              "pattern": "(?i)💾\\s*([0-9.]+\\s*(?:KB|MB|GB|TB))"
            }
          }
        ]
      },
      "seeders": {
        "regex": {
          "from": { "coalesce": ["title", "description"] },
          "pattern": "👤\\s*([0-9]+)"
        }
      }
    }
  }
}
```

Notes on Stremio-shaped addons:

- `behaviorHints.filename` names the selected file and `behaviorHints.videoSize` is its exact size.
- `file_idx` reads the addon's zero-based `fileIdx`. It keeps different files of one torrent as different choices, without skipping the title and episode checks.
- Only a validated `infoHash` is used. An addon's direct-play URL (which can carry a credential) is **never** used.

### What happens when a search runs

You do not need this to write an indexer, but it explains the numbers.

- The engine allows at most **96 new request producers** and **24 HTTP exchanges** at once, hedged mirrors included. One search's planned request list is also capped at 96.
- A cache hit, or a caller joining the same request that is already running, does not start another one.
- Waiting for a permit counts against a host's timeout. Being busy locally is **not** evidence that a mirror is down, and a mirror that was never contacted is not put to rest for losing a hedge.
- A successfully read answer is cached **ten minutes** when it has rows and **sixty seconds** when it is empty. The cache key includes the definition version, the endpoints and the filled request. HTTP errors, malformed or blocked answers, timeouts and busy failures are **not** cached as healthy empty answers.
- Releases from different requests that share `(hash, file_idx)` are merged before ranking. The `sources` list follows the planned order, not the arrival order. Seeder counts use the **maximum**, never a sum. Trackers are limited to the signed list (at most 32).
- Having a hash in two places is not proof of the right title or episode. Matching happens in code, after reading: title, aliases, season, episode and a film's year, again on the actual filenames. The server also probes the media and budgets preparation per stream source. You cannot change those rules by publishing data.
- A definition that passes the check, or parses a sample, does **not** prove the site is reachable, the content is right, or playback holds up.

---

## Providers

A provider is one catalogue. It answers four questions: what is on this page of a list, what matches this search, what is this one title in full, and (inside that) what are its episodes, cast and related titles.

Here is a small real one, TVMaze:

```json
{
  "id": "tvmaze",
  "kinds": ["series"],
  "base_url": "https://api.tvmaze.com",
  "card": {
    "id": "id",
    "title": "name",
    "poster": { "coalesce": ["image.original", "image.medium"] },
    "format": { "coalesce": ["type", { "const": "TV" }] },
    "status": "status",
    "year": { "year": "premiered" },
    "runtime_minutes": { "coalesce": ["averageRuntime", "runtime"] },
    "score": { "scale": { "from": "rating.average", "by": 10 } },
    "popularity": "weight",
    "genres": "genres"
  },
  "list": {
    "request": { "url": "{base}/schedule/full" },
    "rows": "_embedded.show",
    "ttl_secs": 21600,
    "dedupe": "id",
    "drop": [
      { "path": "image", "exists": false },
      { "path": "premiered", "after_today": { "grace_days": 30 } }
    ],
    "genre": "genres",
    "order": {
      "default": [
        { "by": "weight", "compare": "number", "descending": true },
        { "by": "rating.average", "compare": "number", "descending": true },
        { "by": "premiered", "descending": true }
      ],
      "title": [{ "by": "name", "compare": "caseless" }]
    },
    "paging": { "per_page": 24, "max": 50, "style": "pool" }
  },
  "search": {
    "request": { "url": "{base}/search/shows?q={term}" },
    "rows": "show",
    "drop": [{ "path": "image", "exists": false }]
  },
  "detail": {
    "request": {
      "url": "{base}/shows/{id}?embed%5B%5D=episodes&embed%5B%5D=cast"
    },
    "id_pattern": "^[0-9]+$",
    "root": "",
    "description": { "plain_text": "summary" },
    "count_episodes": true,
    "imdb_id": {
      "regex": { "from": "externals.imdb", "pattern": "^(tt[0-9]+)$" }
    },
    "studios": "network.name",
    "episodes": {
      "rows": "_embedded.episodes",
      "id": { "template": "series-{^.id}-s{season}e{number}" },
      "season": "season",
      "number": "number",
      "name": "name",
      "airdate": "airdate"
    },
    "cast": {
      "sources": [
        {
          "rows": "_embedded.cast",
          "name": "person.name",
          "role": "character.name",
          "image": "person.image.medium"
        }
      ]
    }
  },
  "image_hosts": ["tvmaze.com"]
}
```

### The parts of a provider

| Part | Needed? | What it is |
| --- | --- | --- |
| `id` | yes | A unique id. |
| `kinds` | yes | The kinds of title it has. |
| `base_url` | yes | The `{base}` of every request. A service that moves is one change. Must start with `http://` or `https://` and have **no braces** in it. |
| `types` | no | What the service calls each kind: the `{type}` of a request. |
| `sorts` | no | What the service calls each sort: the `{sort}` of a request. `default` covers a sort that is not named, and a request with no sort. |
| `card` | yes | How a title is read, once. |
| `list` | no | A page of titles. |
| `search` | no | A search. |
| `detail` | yes | One title in full. |
| `image_hosts` | no | The hosts its pictures live on. At most 16. |

**`image_hosts`**: the website's image proxy fetches a picture **only** from these hosts (an entry matches that host and its subdomains), from the hosts other providers name, and from ones the operator adds with the `IMAGE_HOSTS` setting. Give a bare host name, with no `https://`, no path and no port.

### Requests in a provider

A request has a `url`, and optionally `method` (`GET` or `POST`), `query` and a `json` body.

- The `url` is the **whole address** and **must start with `{base}/`** (or be exactly `{base}`). That way what is searched for can only ever go *after* the service's own address.
- Holes in a provider request (each is percent-encoded): `{base}`, `{type}`, `{sort}`, `{id}`, `{term}`, `{page}`, `{per_page}`, `{skip}`, `{genre}`, `{genre_lower}` and `{year}`.
- A hole with nothing to fill it empties the address. `{? ... ?}` is left out when a hole inside is empty.
- In a JSON body, `$text`, `$number`, `$sort`, `$kind` and `?` keys work as described under [Templates](#templates-and-holes-in-requests).

AniList, for example, is asked in GraphQL:

```json
{
  "method": "POST",
  "url": "{base}",
  "json": {
    "query": {
      "$text": "query ($page: Int, $perPage: Int, $sort: [MediaSort], $genre: String) { Page(page: $page, perPage: $perPage) { pageInfo { hasNextPage } media(type: ANIME, sort: $sort, genre: $genre) { id title { romaji english native } } } }"
    },
    "variables": {
      "page": { "$number": "{page}" },
      "perPage": { "$number": "{per_page}" },
      "sort": "{sort}",
      "genre?": "{genre}"
    }
  }
}
```

(That one is shortened to show the shape. The real one asks for more fields.)

### `card`: how a title is read

`card` is used for every title the provider gives you, wherever it gives one (a list, a search, a title in full, related titles).

| Field | Needed? | What it is |
| --- | --- | --- |
| `id` | yes | The service's own id. The title's key is made from the kind and this. |
| `title` | yes | The title. |
| `title_variants` | no | Other names, gathered without repeats. By default, the title alone. |
| `poster`, `banner` | no | Picture addresses. |
| `description` | no | The synopsis. (A page of titles often has none; use `detail.description`.) |
| `format` | no | `TV`, `MOVIE` and so on. |
| `status` | no | Airing, ended and so on. |
| `year` | no | The year. |
| `episodes` | no | The number of episodes. |
| `runtime_minutes` | no | Minutes. |
| `score` | no | **Out of 100.** Use `scale` to convert (`by: 10` for a score out of 10). |
| `popularity` | no | A number the provider ranks by. |
| `genres` | no | A list of genre names. |
| `adult` | no | Whether the title is adult. |

### `list`: a page of titles

| Field | Needed? | What it is |
| --- | --- | --- |
| `request` | yes | The request (see above). |
| `rows` | yes | The path to the rows, as for an indexer. |
| `check` | no | How to tell an answer is an error even though it arrived (see below). |
| `ttl_secs` | no | How long an answer is reused. Default 600. At most 86400 (a day). |
| `dedupe` | no | Rows with the same value here are one title. The first counts. |
| `drop` | no | Rows to leave out (conditions). |
| `paging` | yes | How the service pages (see below). |
| `genre`, `year` | no | How a row names its genres and its year, for the rows that are filtered *here* because the service cannot. |
| `order` | no | How rows that are sorted here are ordered, by sort name (and `default`). |

An `order` is a list of keys. Rows are compared by the first key, then by the next:

```json
[
  { "by": "rating.average", "compare": "number", "descending": true, "missing_last": true },
  { "by": "name", "compare": "caseless" }
]
```

- `by` is an expression.
- `compare` is `text` (default), `caseless` or `number`.
- `descending` flips the order.
- `missing_last: true` puts rows with nothing there after the rest, instead of counting them as 0 (or as empty text).

### Paging

`list.paging` always has `per_page` (default 24, and never more than `max`) and `max` (default 50, between 1 and 200). Then it picks a `style`:

**`page`**: the service pages. It is asked for page `{page}` of `{per_page}`.

```json
{
  "per_page": 24,
  "max": 50,
  "style": "page",
  "next": { "flag": "data.Page.pageInfo.hasNextPage" }
}
```

- `next` says whether more follows: `{"flag": "<path>"}` (a true value there) or `{"total": "<path>"}` (a count that is more than the rows so far).
- Optional `widen`: `{"when": ["genre"], "per_page": 100}`. When one of the `when` holds, a wider page is asked for and the rows are filtered here (with no next page), for a service that cannot filter by that.

**`skip`**: the service pages by `{skip}`, `size` rows at a time.

```json
{
  "per_page": 24,
  "max": 50,
  "style": "skip",
  "size": 25,
  "window": { "when": ["genre", "year"], "pages": 4 }
}
```

- `window`: when one of the `when` holds (the service cannot filter or order that way), `pages` pages are read from the start and the page is cut from those here.
- `size` must be above 0, and `max` divided by `size` (rounded up) must be at most 4. `window.pages` is 1 to 4.

**`pool`**: the service has no paging. It is asked once and the page is cut here.

```json
{ "per_page": 24, "max": 50, "style": "pool" }
```

`when` entries can only be `genre`, `year` or `sort:<name>`.

### `search`

`search` has `request`, `rows`, optional `check`, `ttl_secs`, `drop`, `per_page` (how many rows it asks for) and `next` (the same `flag` or `total`; without it there is no next page).

### `detail`: one title in full

| Field | Needed? | What it is |
| --- | --- | --- |
| `request` | yes | The request. Use `{id}`. |
| `id_pattern` | no | The ids the service has, as a regex. Anything else is not asked for: the title is "not there". |
| `check` | no | How an answer reports it failed. |
| `root` | no | Where the title is in the answer. The paths below start there. |
| `missing` | no | Conditions: a title matching any of these does not exist (a service that answers with a placeholder). |
| `description` | no | Where the synopsis is. |
| `count_episodes` | no | `true`: the number of episodes is the number listed. |
| `imdb_id` | no | Where the IMDb id is. Releases are searched with it. |
| `studios` | no | Studio or network names. |
| `trailer` | no | `{"site": ..., "id": ...}`. |
| `episodes` | no | The episode list (below). |
| `cast` | no | The cast (below). |
| `related`, `recommended` | no | Other titles (below). |

**`episodes`**:

```json
{
  "rows": "_embedded.episodes",
  "id": { "template": "series-{^.id}-s{season}e{number}" },
  "season": "season",
  "number": "number",
  "name": "name",
  "airdate": "airdate",
  "drop": []
}
```

`id` is the episode's whole media id. `season`, `number` and `id` are required. For a plugin catalogue the **app** makes the episode ids, not the provider's `episodes.id`.

**`cast`**: `{ "sources": [ { "rows": ..., "name": ..., "role": ..., "image": ... } ], "limit": 12 }`. The first source that has anyone is used. `limit` defaults to 12.

**`related`** and **`recommended`**: `{ "request": ..., "check": ..., "rows": ..., "drop": [], "limit": 12 }`. With a `request`, they are asked separately and a failure leaves the list empty. Without one, the rows are in the title's own answer, below its root.

**`check`**: how to tell an answer is an error even though it arrived.

```json
{
  "error": "errors",
  "message": "errors.0.message",
  "ok": { "path": "status", "equals": "ok" }
}
```

- `error`: an answer that has anything at this path failed.
- `ok`: an answer must satisfy this condition to have worked.
- `message`: where the answer says why it failed. That text is what is shown.

---

## Chains

`chains` says which providers answer for each kind, in order.

```json
{
  "anime": ["anilist"],
  "series": ["cinemeta", "tvmaze"],
  "movie": ["cinemeta", "yts"]
}
```

- The first provider in the list answers. If it returns nothing or fails, the next one answers. An outage makes a row smaller, not empty.
- Each built-in kind needs 1 to 8 providers. A provider can appear only once per kind. Every one named must exist and serve that kind.
- Plugin catalogues are **not** part of a chain. They are searched in addition, after the built-in results.

---

## Mappers

A mapper finds the id a title has in another service. An indexer that knows titles by *that* id can then be asked for it. The built-in mapper turns an AniList anime id into a Kitsu id, so Torrentio can be asked for the exact episode.

```json
{
  "id": "kitsu",
  "kinds": ["anime"],
  "provider": {
    "id": "anime-kitsu",
    "kinds": ["anime"],
    "base_url": "https://anime-kitsu.strem.fun",
    "card": {
      "id": "kitsu_id",
      "title": "name",
      "format": "type",
      "year": { "year": "releaseInfo" }
    },
    "detail": {
      "request": { "url": "{base}/meta/anime/anilist:{id}.json" },
      "id_pattern": "^[0-9]+$",
      "root": "meta",
      "episodes": {
        "rows": "videos",
        "id": "id",
        "season": "season",
        "number": "episode"
      }
    }
  }
}
```

How to use one:

- `id`: lower case letters only. It names the holes of an indexer's request (`{kitsu}` and `{kitsu_kind}`) and the front of the ids the mapper's answer must hold: `kitsu:<title>:<episode>`, or `kitsu:<title>` for a film.
- It cannot be one of the names an indexer's request already has: `term`, `imdb`, `imdb_digits`, `imdb_or_term`, `season`, `episode`.
- `kinds`: the kinds it maps. Its provider must serve every one of them.
- `provider` is asked for the detail of the title, by **our own id** (AniList's, digits). Its `episodes` give the other service's id of each episode.
- An indexer opts in with `"map": "kitsu"` and puts `{kitsu}` and/or `{kitsu_kind}` in its request.

The safety rule: the mapper accepts **only an exact same-number episode** (`kitsu:7442:1`). A film uses its exact unsuffixed title id (`kitsu:50192`) and the `movie` route. An answer that does not hold exactly the requested episode, in exactly that shape, is **no mapping**, and that indexer is skipped. It never falls back to the IMDb id or plays another episode.

---

## Subtitles

A subtitle source is one site that has subtitle files.

```json
{
  "id": "opensubtitles",
  "name": "OpenSubtitles",
  "kinds": ["series", "movie", "anime"],
  "hosts": ["https://opensubtitles-v3.strem.io"],
  "file_hosts": ["strem.io"],
  "lookup": {
    "kinds": ["anime"],
    "url": "https://v3-cinemeta.strem.io/catalog/series/top/search={term}.json",
    "rows": "metas",
    "value": "imdb_id",
    "max_episodes": 30,
    "skip_title": "(?i)(season\\s*\\d|\\d(?:st|nd|rd|th)\\s+season|part\\s*\\d|cour\\s*\\d|final\\s+season|\\bii+\\b|\\bs\\d\\b)"
  },
  "request": {
    "path": {
      "$kind": {
        "movie": "/subtitles/movie/{imdb}.json",
        "series": "/subtitles/series/{imdb}:{season}:{episode}.json",
        "anime": "/subtitles/series/{imdb}:1:{episode}.json"
      }
    }
  },
  "response": {
    "rows": "subtitles",
    "fields": {
      "id": "id",
      "url": "url",
      "lang": "lang",
      "label": { "coalesce": ["subtitleFileName", "movieReleaseName"] },
      "format": { "const": "srt" }
    }
  }
}
```

| Field | Needed? | What it is |
| --- | --- | --- |
| `id`, `name` | yes | The id and the name shown as where a subtitle came from. |
| `kinds` | yes | The kinds it serves. |
| `hosts` | yes | 1 to 8 mirrors, tried in order. |
| `cooldown_secs` | no | How long a failing host rests. Default 60. At most 3600. |
| `file_hosts` | yes | 1 to 16 **bare host names**. A subtitle file is fetched **only** from these (a host is allowed when it is one of them or a subdomain of one), whatever an answer names. |
| `lookup` | no | Finds an IMDb id for a title that has none (anime). |
| `request` | yes | Like an indexer's request. Holes: `{imdb}`, `{season}`, `{episode}`, `{term}` (the title) and `{year}`. |
| `response` | yes | `rows`, `fields` and optional `drop`. |

**Response fields**: `url` and `lang` are required (a language code, two or three letters), and `id` too (what tells one subtitle from another within the service). Optional: `label` (what the viewer reads, usually the release the subtitle was made for), `format` (`srt`, `ass` or `vtt`, and if it is not said it is read from the file) and `hearing_impaired` (anything but empty, `false` or `0` says yes).

**`lookup`**: asks `url` (with `{term}` filled in), reads `rows`, and takes `value` from the first row. It is skipped for a title with more than `max_episodes` episodes (its numbering would not match the subtitle service's) and for a title whose name matches `skip_title` (a later season, whose episodes the service would number differently).

A subtitle is converted to WebVTT, which both the web player and mpv read.

---

## Screens

`screens` says what the apps draw, so the desktop app and the website show the same thing from one place. The server sends it at `GET /v1/screens`.

```json
{
  "tabs": [
    { "kind": "anime", "slug": "anime", "label": "Anime", "tag": "ANIME" },
    { "kind": "series", "slug": "series", "label": "Series", "tag": "SERIES" },
    { "kind": "movie", "slug": "films", "label": "Films", "tag": "FILM" }
  ],
  "sorts": [
    { "sort": "popularity", "label": "Popular" },
    { "sort": "trending", "label": "Trending" },
    { "sort": "score", "label": "Top rated" },
    { "sort": "recent", "label": "Newest" },
    { "sort": "title", "label": "A–Z" }
  ],
  "genres": {
    "anime": ["Action", "Comedy"],
    "series": ["Drama"],
    "movie": ["Documentary"],
    "all": ["Action", "Drama"]
  },
  "home": [
    { "title": "Trending Anime", "kind": "anime", "sort": "trending" },
    { "title": "New Releases", "kind": "movie", "sort": "recent" },
    { "title": "Action Anime", "kind": "anime", "sort": "popularity", "genre": "Action" }
  ],
  "about": {
    "attribution": "Metadata from AniList, Cinemeta and TVMaze (CC BY-SA). Akidev stores no media: playback links are resolved from public sources when you press play.",
    "catalogues": ["AniList", "Cinemeta", "TVMaze", "YTS"],
    "subtitles": ["OpenSubtitles"]
  }
}
```

- **`tabs`** are the catalogues, in the order of the top bar.
  - `kind` is the kind it shows.
  - `slug` is the address on the website (`/films`). It is lower case letters and dashes only, and it **cannot** be a page the site already has: `search`, `title`, `watch`, `download`, `privacy`, `manga`, `info`.
  - `label` is the tab and the page heading.
  - `tag` is the small label over a title of that kind (`FILM`).
  - 1 to 16 tabs. Every slug, kind and label must be unique.
- **`sorts`** are the ways a catalogue can be ordered. The first one is the one it opens on. 1 to 16.
- **`genres`** are offered for one catalogue, by kind name, in the providers' **own spellings** (AniList and Cinemeta spell some differently, and a genre one of them lacks only ever returns nothing). `all` is for the page that shows every catalogue. Up to 64 per kind. A key must be `all` or a real kind.
- **`home`** are the rows of the home page, in order (1 to 32). `genre` is optional. A row's `kind` must have a tab. A row can name a `provider` to draw from that one alone.
- **`about`** is the credit text:
  - `attribution` is the footer line (1 to 1000 characters).
  - `catalogues` and `subtitles` are the names the privacy page lists (up to 32 each, 1 to 64 characters per name).
  - **When you add or drop a source, change these too.** The website has no list of its own.

---

## Plugins

A plugin is how a **user** adds sources of their own, without touching this file. It is one JSON file (plus an optional `.wasm` file for code). Only the **desktop app** loads plugins. The server and the website never do.

Nobody signs a plugin, so it is held to **stricter rules** than the document above, and the app shows it as "unverified".

### Where plugins live

- The app keeps plugins in `<data folder>/plugins`.
- `name.json` is **on**, and `name.json.off` is **off**.
- If a plugin has code, its module sits beside it as `<id>.wasm`.
- Settings lists them, switches them on and off, removes them, and adds one from a link (https, followed once, never redirected, 256 KB at most). A link is fetched once: to update a plugin, add its link again.

### The smallest plugin

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
      "response": {
        "format": "json",
        "rows": "items",
        "fields": { "title": "title", "hash": "hash" }
      }
    }
  ]
}
```

### What a plugin can bring

| Key | What | Limit |
| --- | --- | --- |
| `indexers` | Torrent sites. Same shape as in the document. | 16 |
| `subtitles` | Subtitle sources. Same shape. | 4 |
| `providers` | Catalogues. Same shape, with the extra rules below. | 4 |
| `home` | Rows for the home page, each from one of the plugin's own catalogues. | 8 |
| `kinds` | New kinds of title, each with a tab. | 4 |
| `mappers` | Id mappers. Same shape. | 2 |
| `services` | Stream services (need `module`). | 2 |
| `module` | A WebAssembly file for what JSON cannot say. | 4 MB |

A plugin must bring at least one thing. Its whole file is at most **256 KB**.

### Rules every plugin follows

- `plugin` is the format number, and it must be `1`.
- `id` is 1 to 40 lower case letters, digits or dashes, and **it is the name of the file the plugin is kept in**. `name` is 1 to 60 characters.
- **Every address** must be `https`, on a public name, with no login and no port. No IP address, no `localhost`, no `.local`, `.internal`, `.intranet`, `.private`, `.corp`, `.home`, `.lan`, `.localdomain` or `.home.arpa` name. (A public name that points at a private address is not caught.)
- These headers may not be set: `host`, `content-length`, `transfer-encoding`, `connection`, `upgrade`, `te`, `trailer`, `expect`.
- A plugin adds its sources **after** the built-in ones. A source whose id is already taken is refused, so a plugin can **add but never replace**.
- A plugin that is a bad update keeps the old copy. A plugin that would stop another one working is refused.
- The plugin can only use a kind that always exists or that it brings itself.

### Catalogues (providers) in a plugin

```json
{
  "plugin": 1,
  "id": "docs",
  "name": "Documentaries",
  "version": 1,
  "kinds": [
    { "id": "documentary", "label": "Documentaries", "singular": "Documentary", "shape": "series" }
  ],
  "providers": [
    {
      "id": "myprovider",
      "kinds": ["documentary"],
      "base_url": "https://catalogue.example.com/api",
      "card": { "id": "id", "title": "name" },
      "list": {
        "request": { "url": "{base}/list" },
        "rows": "items",
        "paging": { "style": "pool" }
      },
      "search": {
        "request": { "url": "{base}/search?q={term}" },
        "rows": "items"
      },
      "detail": {
        "request": { "url": "{base}/title/{id}" },
        "root": "",
        "episodes": {
          "rows": "episodes",
          "id": "id",
          "season": "season",
          "number": "number",
          "name": "name"
        }
      },
      "image_hosts": ["images.example.com"]
    }
  ],
  "home": [
    { "title": "Community picks", "kind": "documentary", "sort": "popularity", "provider": "myprovider" }
  ]
}
```

- A plugin catalogue has an id of 1 to 24 lower case letters or digits (no dash, because a title key is split at the first dash after the provider).
- Every address in it (its `base_url`, its `image_hosts`) follows the https rule above.
- Its titles say which provider they came from: `series-myprovider~abc_2d12` is the title `abc-12` of `myprovider`. Every character of the service's own id that is not a letter or a digit is written as `_` and two hex digits. So they never collide with the built-in catalogues. The **app** makes the episode ids, not the provider's `episodes.id`.
- A plugin catalogue is **not** part of a kind's chain, and it has no tab of its own. Its titles are added to every search, after the built-in results.
- `home` rows are drawn from one catalogue of the plugin alone: `provider` is required and must be one of the plugin's own catalogues that serves the row's kind. They come after the built-in rows.

### Kinds in a plugin

```json
{ "id": "documentary", "label": "Documentaries", "singular": "Documentary", "shape": "series" }
```

- `id`: 1 to 16 lower case letters, and **not** a kind that already exists.
- `label` is the tab and the page heading. `singular` is what one title is called (default: the label). Both are 1 to 30 characters.
- `shape` is `series` (seasons and episodes, keys like `documentary-…-s1e2`), `anime` (episodes by number, `-ep3`) or `movie` (no episodes).
- A kind has no built-in catalogue, so its tab lists from the plugin's own, and its titles show in search with the others.
- A kind a plugin brought **stays known** after the plugin is removed, so saved titles still read.

### Mappers in a plugin

Same shape as in the document. An indexer of the plugin names one with `map`, and its holes are `{<id>}` and `{<id>_kind}`. A mapper cannot take the id of one that already exists.

### Code (WebAssembly) in a plugin

JSON cannot sign a request, log in, or read an HTML page. For that, a plugin brings a **module**.

```json
{
  "plugin": 1,
  "id": "signed-torrents",
  "name": "Signed torrents",
  "version": 1,
  "module": {
    "file": "signed-torrents.wasm",
    "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
  },
  "indexers": [
    {
      "id": "signed-torrents",
      "name": "Signed torrents",
      "kinds": ["series"],
      "hosts": ["https://torrents.example.com"],
      "code": "search",
      "request": { "path": "/list", "query": { "q": "{term}" } },
      "response": {
        "format": "json",
        "rows": "items",
        "fields": { "title": "title", "hash": "hash", "seeders": "seeders" }
      }
    }
  ]
}
```

(The `sha256` above is a placeholder. Use the real hash of your module.)

How it works:

- `module.file` is a plain lower case name ending in `.wasm`, and `module.sha256` is 64 lower case hex digits. The file sits **next to the plugin JSON on the same host**, is at most **4 MB**, must be a real WebAssembly file, and is refused if its hash differs.
- An indexer, a catalogue (provider), or a mapper's provider names an export of the module in `code` (1 to 32 lower case letters, digits or `_`).
- The module makes **only the request step** and answers with JSON. The source's own `response` (or `card`, `list`, `detail`) then reads that JSON like any other answer. So every normal check (the hash, the episode rules, the ranking) still applies, and a module cannot get a release past them.
- The module needs at least one source that uses it, and a source that asks for `code` needs the module.

What a module can do:

- It runs in a sandbox. No files. No clock. Its **only** network is one host call, `akidev.http`, which only reaches the hosts the source declares, over public https.
- Limits for each call: **300 million instructions, 64 MB of memory, 20 seconds, 8 requests, answers up to 2 MB**.
- Redirects to private hosts are refused, and the forbidden headers above are refused.
- Signing and HTML reading are compiled into the module itself, so the app offers no crypto and no parser.

The interface (JSON in, JSON out over the module's memory):

- Exports: `memory`, `alloc(len) -> ptr`, and one function per job that takes `(ptr, len)` and returns `(ptr << 32) | len` of the JSON it wrote.
- Imports: `akidev.http(ptr, len)` (one request: `{method, url, headers, body}` in, `{status, body}` or `{error}` out) and `akidev.log(ptr, len)`.

Working examples are `desktop/plugins/code-indexer` and `desktop/plugins/snowfl` in the code repo. A **signed** `sources.json` can never carry `code`.

### Stream services in a plugin

A stream service turns a release into a playable https link, the way a debrid service does. It needs `module`. Only the desktop app uses it.

```json
{
  "plugin": 1,
  "id": "torbox",
  "name": "TorBox",
  "version": 1,
  "module": {
    "file": "torbox.wasm",
    "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
  },
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

| Field | What it is |
| --- | --- |
| `id` | 1 to 24 lower case letters, digits or dashes. Settings keeps the key under this id. |
| `name` | 1 to 40 characters. |
| `export` | The export that does the work. Default `resolve`. |
| `base` | The https address of the API, given to the module. It must be on one of the `hosts`. |
| `hosts` | 1 to 4 bare host names the module may call. |
| `media_hosts` | 1 to 4 bare host names the returned link may be on (a subdomain matches). |
| `key_label` | What Settings calls the key. Leave it out for a service with no key. |

How it plays:

1. The viewer types their key in Settings, under **Stream services**. It is kept in the settings file (readable only by them) and given **only** to this module.
2. At play time, enabled services are asked **before** the torrent engine, for the best few releases.
3. The app calls the module for `files` (what the service holds for the release). The module answers `{"status": "files", "files": [{"id", "name", "size"}], "state": ...}` or `{"status": "unavailable", "reason": ...}`.
4. The **app** picks the file for the episode, with its own code. A module never decides that.
5. The app calls the module for `link` with the chosen file's id. The module answers `{"status": "ready", "url": ...}`.
6. At any step a module may answer `{"status": "retry", "after_ms": 700, "state": ...}`. The app waits and calls again with the `state` it was given. (A module has no clock, so the app does the waiting.)
7. The link must be https, on a public host, and on one of `media_hosts`. It is handed to the player as it is and never stored.
8. When no service has the release, the torrent engine runs as before.

A working example is `desktop/plugins/torbox` in the code repo. The full protocol is in `pipeline/WASM_PLUGINS.md` there.

---

## Recipes

### Add a torrent site

1. Find a request that returns the list you want (try it with `curl`).
2. Write an indexer: `id`, `name`, `kinds`, `hosts`, `request`, `response`. Start from [Nyaa](#indexers) for RSS or [Knaben](#real-example-a-json-get-knaben) for JSON.
3. Pick the right `fanout`.
4. Add `empty_when` if a successful empty answer leaves the list out.
5. Raise `version`, check, test against the real site, publish.

### Add a mirror

Add the address to the end of the indexer's `hosts`. Keep the best mirror first.

### Add a catalogue

1. Write a provider (start from [TVMaze](#providers)).
2. Add its id to the right `chains` entry. Decide whether it goes first or is a backup.
3. Put its picture hosts in `image_hosts`.
4. Add its name to `screens.about.catalogues` so the credits are right.
5. Make sure its genres match the spelling in `screens.genres`.

### Add a subtitle source

Copy the [OpenSubtitles](#subtitles) entry, change the hosts, the request and the fields, and set `file_hosts` to where the files live.

### Add a tab or a home row

Edit `screens.tabs` or `screens.home`. A row's `kind` must have a tab. A new tab slug must not be a reserved page.

### Change the credits

Edit `screens.about`. The footer and the privacy page read it.

### Remove a source

Delete it from `indexers` or `providers` and from any `chains` entry that names it. If a home row names it, change the row. Raise `version`.

### Roll back a bad publish

You cannot go back to a lower version. Fix the file (or restore the old one) and publish it with a **higher** `version`.

### Make an indexer server-only

Add `"server_only": true`. Use it for a source that needs a key only your server has.

---

## Let an agent write a source for you

This repo has a Claude skill, `akidev-sources`, in `.claude/skills/akidev-sources/`. When you work in this repo with Claude Code, you can give it a website, an API, a feed or an idea, and it writes the whole thing.

Just say what you want, for example:

- "Add https://example.com as a torrent source."
- "Add this catalogue API: https://api.example.com/docs."
- "Write me a plugin for this site. It is only HTML."
- "I have a debrid service with this API. Make a stream service plugin."

What it does:

1. Looks at the site with `curl`: is it JSON, RSS, Torznab, a Stremio addon, GraphQL, or only HTML? It saves real answers.
2. Decides what to build (an indexer, a provider, a subtitle source, a mapper, a code plugin, or a stream service) and where it goes: here in `sources.json` for everyone, or as a plugin for one app.
3. Writes it from a template in `.claude/skills/akidev-sources/templates/`.
4. Tests it with the scripts in `.claude/skills/akidev-sources/scripts/`: the real rules (`check-source.sh`), a real local search (`try-local.sh`), and, for a code plugin, building and hashing the module (`build-plugin.sh`) and running it against the real site (`try-module.sh`).
5. Hands you the files, how to install them, and what it could not verify. It does **not** publish unless you ask.

The scripts need a checkout of the code repo, [dishant0406/akidev](https://github.com/dishant0406/akidev), next to this one (as `../akidev`), or set `CODE_REPO` to where it is.

It will not try to get around a site's protections (a challenge page, a captcha, a login wall), and it will not put a key in `sources.json`.

---

## Troubleshooting

- **My publish was refused: "not newer".** Raise `version` above the live one. Check what is live with `curl -s https://sources.akidev.live/sources.json | jq .version`. The daily tracker job raises the live version too, so the live one can be ahead of this file.
- **The old-app check refused it.** An old app refuses a whole document with a value it does not know. Either set `OLD_REF` to the oldest release you still support, or ship the app first. Fields are fine; new *values* are the problem.
- **An indexer never finds anything.** Run its request by hand. Check the hole names, the `rows` path, and the field paths against a real answer. A request that needs `{imdb}` for a title with no IMDb id is not made at all.
- **A catalogue row is empty.** Check `drop` (an overly strict condition removes everything) and `paging`. Check the provider's `check` for an error answer.
- **A document was refused by the checker.** Read the first line of the error. Common causes: a duplicate id, a bad regex, a provider `url` that does not start with `{base}/`, a chain that names a provider that does not serve the kind, a home row whose kind has no tab, a tab slug that is reserved.
- **A new field is ignored by users.** Apps that predate the field ignore it. Publish the file first, then ship the app or server that needs it.
- **Something works in the check but not for users.** The check cannot know if a mirror is alive, if a GraphQL selection is right, or if an episode is the right one. Always test against the real service.

---

## What the file cannot do

These are engine behaviour, so changing them needs a code change and a new build:

- The ranking and filtering rules (what counts as the right title, episode, season or year; samples and extras; HEVC and AV1 treated as "extra").
- The three shapes (`anime`, `series`, `movie`) and the id rules.
- The music sources (YouTube Music and Audius) and, on the server, TorBox and the Internet Archive.
- Anything that needs a key kept secret (the file is public).
- Running code: a signed document can never carry code or stream services. Plugins can.

A service that needs something these cannot say needs a change to the engine in `core/src/providers/` (or `core/src/indexers/`), and so a new build.

---

## All the limits in one place

| What | Limit |
| --- | --- |
| Document size | 1 MiB |
| `version` | at most 2^40 |
| `trackers` | 32 |
| `indexers`, `providers` | 1 to 64 each |
| `mappers`, `services` (in use) | 8 |
| `subtitles` | 16 |
| Hosts per indexer or subtitle source | 1 to 8 |
| `file_hosts` per subtitle source | 1 to 16 |
| `image_hosts` per provider | 16 |
| `cooldown_secs` | at most 3600 |
| `min_interval_secs` | at most 3600 |
| `max_requests_per_day` | greater than 0 when present |
| `ttl_secs` | at most 86400 |
| Providers in one chain | 1 to 8, no repeats |
| `min_version_message` | 300 characters |
| `paging.max` | 1 to 200; `per_page` 1 to `max` |
| Tabs, sorts | 1 to 16 each |
| Genres per kind | 64 |
| Home rows | 1 to 32 |
| `about.attribution` | 1 to 1000 characters |
| New request producers at once | 96 |
| HTTP exchanges at once | 24 |
| A cached answer with rows / empty | 10 minutes / 60 seconds |
| Plugin file | 256 KB |
| Plugin indexers / subtitles / catalogues / home rows / kinds / mappers / services | 16 / 4 / 4 / 8 / 4 / 2 / 2 |
| Plugin module | 4 MB |
| A module call | 300 million instructions, 64 MB, 20 s, 8 requests, 2 MB answers |

Where the code lives, in the code repo: the format is in `desktop/core/src/definition.rs`, the document and its checks in `desktop/core/src/sources.rs`, the screens in `desktop/core/src/screens.rs`, plugins in `desktop/core/src/plugin.rs`, the sandbox in `desktop/core/src/code.rs`, and stream services in `desktop/core/src/services.rs`.
