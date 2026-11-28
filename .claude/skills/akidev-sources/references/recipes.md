# Recipes

Each recipe says what to do, in order, with the commands. Run commands from `<code repo>/desktop` unless it says otherwise. `SOURCES_DIR` is the checkout of the sources repo.

Common to every recipe: **raise `version`**, keep the JSON formatted, validate, test, and only publish when the user asks. The common commands:

```bash
# validate the file on its own
cargo run -p akidev-core --bin akidev-sources -- check "$SOURCES_DIR/sources.json"

# run the engine's tests against your copy (the build only downloads sources.json when this file is missing)
cp "$SOURCES_DIR/sources.json" sources/sources.json
cargo test -p akidev-core
```

## Contents

1. Add a torrent site (indexer)
2. Add a mirror to an indexer
3. Fix an indexer that reads wrong
4. Add a catalogue (provider)
5. Add or fix a release date
6. Add a subtitle source
7. Add a mapper
8. Add a tab, a sort, a genre or a home row
9. Change the credits
10. Remove a source
11. Make a source server-only
12. Add a fallback indexer
13. Lock out old apps
14. Add a test fixture for a new source
15. A source needs a key, a login or HTML scraping

---

## 1. Add a torrent site (indexer)

1. **Find the request.** Use `curl` to get a list for a real title. Note the URL, the method, the query or body, and any header the site wants.

   ```bash
   curl -s 'https://example.com/api?q=breaking+bad' | jq . | head -60
   ```

2. **Look at one row.** Find where the rows are (the path), and where the title, the info hash, the size and the seeders are in a row. If the site returns RSS, rows are the items and tags are read by name (`tag@attribute` for attributes).
3. **Pick the closest existing indexer to copy.**
   - RSS: `nyaa`.
   - JSON with a POST body and categories: `knaben`.
   - Nested rows (a film with several torrents), and a successful empty answer: `yts`.
   - A Stremio addon asked by IMDb id: `torrentio`.
4. **Write the entry.** `id` (unique, lower case, dashes), `name`, `kinds`, `hosts` (1 to 8 mirrors), `request`, `response`.
5. **Pick `fanout`:**
   - the site takes a title and you ask with and without episode forms: `per-term` (default);
   - the site answers with every episode of a show, or has no episode syntax: `per-title`;
   - the term plays no part, an IMDb id does: `once`.
6. **Use holes** in `path`, `query` or `json`: `{term}`, `{imdb}`, `{imdb_digits}`, `{imdb_or_term}`, `{season}`, `{episode}`. A request that needs a value the search lacks is not made.
7. **Handle empties.** If a successful empty answer leaves the list out, add `empty_when` (see `yts`).
8. **Clean the rows.** `drop` removes unwanted categories. `must_contain_term: true` helps for an index with no category filter. `dedupe.avoid` keeps a bonus clip from standing for a season pack.
9. **Do not set a default for `seeders`** when the site omits health.
10. Raise `version`, validate, add a test (recipe 14), test against the real site, show the diff.

## 2. Add a mirror to an indexer

Append the address to the indexer's `hosts`. The first host is tried first, so keep the best mirror at the front. A host that fails rests for `cooldown_secs`. At most 8 hosts. Every host starts `http://` or `https://`. Raise `version`.

## 3. Fix an indexer that reads wrong

1. Get a fresh real answer with `curl` and save it.
2. Compare it with the paths in the definition: the `rows` path, each field path.
3. Common causes: the site renamed a key; the rows moved one level; a hash is in a magnet link (use `magnet_hash`); the size is text (`1.3 GB` is fine); seeders is text with other words (use `regex`).
4. If rows come back but are the wrong kind of thing, check `drop` and the category in the request.
5. Update the test fixture (recipe 14) with the new answer so it cannot regress.

## 4. Add a catalogue (provider)

1. Find the service's list, search and detail requests. Save a real answer for each.
2. Start from `tvmaze` (REST) or `anilist` (GraphQL, uses `$text` and `$number`).
3. Write `id`, `kinds`, `base_url` (no braces), `card`, `list`, `search`, `detail`, `image_hosts`.
4. Every request `url` starts with `{base}/` (or is `{base}`).
5. Give `card` an `id` and a `title`. Convert scores to out of 100 with `scale`.
6. Decide `paging.style`:
   - the service pages by page number: `page` with `next`;
   - it pages by offset: `skip`;
   - it has no paging: `pool`.
7. If the service cannot filter by genre or year, filter here: set `list.genre` and `list.year` (how a row names them) and `paging` `widen` or `window`.
8. For sort orders the service does not have, add `order` entries.
9. **Put it in a chain.** Add its id to the right `chains` list. Decide whether it goes first or is a backup. It must serve the kind it is listed for.
10. **Credits.** Add its name to `screens.about.catalogues`. If its genre spelling differs, update `screens.genres`.
11. `image_hosts`: add every host its pictures live on (bare names).
12. Raise `version`, validate, add a provider test (recipe 14), test in the real app or a local server, show the diff.

## 5. Add or fix a release date

1. Get a real title answer from the provider. Save it as a test fixture.
2. Find the first public release date. Do not use an upload date, DVD date, end date, or episode date.
3. Add `release_date` to `card`. Use `YYYY-MM-DD` for a full date. Use `YYYY-MM` for a year and month. Use `YYYY` for a year only.
4. Use `coalesce` for a full date with a year fallback. Use `date` for separate year, month, and day fields. Use `regex` with `^(\d{4}-\d{2}-\d{2})` to cut the date from a timestamp. Use `year` to cut the first year from a range.
5. For GraphQL, request all date fields in list, search, detail, related, and recommended selections.
6. Add the same mapping to a mapper's provider card.
7. Raise `version`. Validate the file. Add a provider test that reads the saved answer.
8. Check list, search, and detail rows separately. A search row can have less than a detail row (Cinemeta search rows have the year only).
9. Check a page of upcoming titles. They are the titles with partial dates.
10. State any limit. YTS has a year only, so it cannot send a full date.

## 6. Add a subtitle source

1. Start from `opensubtitles`.
2. Set `hosts`, the request per kind (`$kind` in the path), the `response.rows` and fields (`id`, `url`, `lang` required).
3. Set `file_hosts` to every host the subtitle files are fetched from. Files from any other host are refused.
4. Only add `lookup` if the source is keyed by IMDb id and anime has none.
5. Add its name to `screens.about.subtitles`.

## 7. Add a mapper

1. A mapper needs a provider that, for our own id (AniList's), lists the other service's id of each episode.
2. Copy `kitsu`. The mapper's `id` is lower case letters, not `term`, `imdb`, `imdb_digits`, `imdb_or_term`, `season`, `episode`.
3. The provider's `kinds` must include every kind the mapper maps.
4. Make the episode ids look like `<id>:<title>:<episode>` (or `<id>:<title>` for a film). Anything else is no mapping.
5. In an indexer, add `"map": "<id>"` and use `{<id>}` and `{<id>_kind}` in its request.

## 8. Add a tab, a sort, a genre or a home row

- **Tab:** add to `screens.tabs`: `kind`, `slug`, `label`, `tag`. The slug is lower case letters and dashes and not `search`, `title`, `watch`, `download`, `privacy`, `manga`, `info`. The kind must exist.
- **Sort:** the known sorts are `popularity`, `trending`, `score`, `recent`, `title`. Add a label in `screens.sorts`. A provider needs a `sorts` mapping for it (or a `default`).
- **Genre:** add to `screens.genres[kind]` in the provider's own spelling. A genre a provider lacks only returns nothing.
- **Home row:** add to `screens.home`. Its `kind` must have a tab. `provider` is optional but must serve the kind. `"style": "ranked"` makes it a "Top 10" (ten titles, a big number beside each). Never give a row a `sort` value an older app does not know: it refuses the whole document.

## 9. Change the credits

Edit `screens.about`: `attribution` (1 to 1000 characters), `catalogues` and `subtitles` (names). The website footer and the privacy page read it.

## 10. Remove a source

1. Delete the entry from `indexers` or `providers`.
2. Remove its id from every `chains` list (a chain needs at least one provider).
3. Change any home row that names it.
4. Remove its name from `screens.about`.
5. Raise `version`. The source leaves users' apps when they get the new copy.

## 11. Make a source server-only

Add `"server_only": true` to the indexer. The server (the website's backend) asks it. The desktop app skips it and never calls your server for it. Use it for a source that needs a key only the server has (the `prowlarr` entry).

## 12. Add a fallback indexer

Add `"fallback": true`. It is asked only when the others found nothing worth opening, and it gets a longer time (the `fallback_timeout_ms` setting). Use it for slow services.

## 13. Lock out old apps

Add `min_version` (`major.minor.patch`) and optionally `min_version_message` (up to 300 characters). **Publish the release that version points to first**, so the Update button has something to find. To lift it, publish a document without the field (or a lower one) and a higher `version`.

## 14. Add a test fixture for a new source

A passing check does not prove the definition reads real answers. Capture one and test it, in the code repo:

- **Indexer:** in `desktop/core/src/indexers/extract.rs`, tests call `run("<id>", &body, "term")` with a saved real body and assert the rows. Copy one of the existing tests and replace the body and the assertions.
- **Provider:** in `desktop/core/src/providers/read_tests.rs`, tests feed saved answers to the provider and assert the cards, the episodes, the cast.
- Run `cargo test -p akidev-core`.

## 15. A source needs a key, a login or HTML scraping

Data cannot say that. Options:

- **Needs a server-only secret:** keep it on the server, mark the indexer `"server_only": true`, and add the secret as a server setting (code change).
- **Needs signing, a login or HTML reading, for one user:** a **code plugin** (WebAssembly). See `plugins.md`.
- **A debrid-style service that returns a playable link:** a **stream service plugin**. See `plugins.md`.

Never put a key in `sources.json`.
