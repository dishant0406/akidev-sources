---
name: akidev-sources
description: Work on anything about Akidev's sources, catalogues and plugins. Use when adding, changing, removing, testing, debugging or publishing sources.json: indexers (torrent sites), providers (catalogues such as AniList, Cinemeta, TVMaze, YTS), chains, id mappers, subtitle sources, screens (tabs, sorts, genres, home rows, credits), trackers, min_version, and plugins (JSON plugins, WebAssembly code plugins, stream services). Also use for questions about how the website, server and desktop app read the sources, how a source change reaches users, the signing and publishing flow, and what data can and cannot do.
---

# Akidev sources

You are working in the `akidev-sources` repo, or on something that reads it. This skill is the full guide: the format, the recipes, the plugin rules, the publishing flow and the debugging steps. Read the references for the details. This file is the map and the rules.

## What this repo is

- It holds **one file**, `sources.json`, plus `README.md`. It is data only: no code, no keys.
- The code that reads, checks, signs and publishes the file is in the other repo, `dishant0406/akidev`, under `desktop/`. In this skill `<code repo>` means a checkout of it and `SOURCES_DIR` means a checkout of this repo. The usual layout is two folders side by side: `.../akidev` and `.../akidev-sources`.
- The document says where Akidev looks for titles, releases and subtitles, and what the screens show. Nothing in it is code. It says which requests to make and which fields to read.
- Every build of the app and the server has a built-in copy (`desktop/core/build.rs` downloads it from this repo's `main` branch when `desktop/sources/sources.json` is missing). Running apps also fetch newer signed copies from `sources.akidev.live` about every 6 hours.

## The golden rules

1. **Raise `version` on every change that will be published.** A new copy must be higher than what is live, or apps ignore it. Plugins excepted: they have their own `version`.
2. **Compare with the live copy before you publish.** The daily tracker job raises the live `version` and rewrites `trackers`, so live can be ahead of this repo. Check with `curl -s https://sources.akidev.live/sources.json | jq .version`. See `references/publishing.md`.
3. **Never publish unless the user asks.** Editing and testing are free. Publishing is outward-facing: it changes what every user's app does within hours. Say what you will publish and get a yes first, unless the user already told you to publish.
4. **Never put a secret or code in `sources.json`.** It is public. A signed document can never carry `code` (WebAssembly) or `services`: they are plugin-only, and a document with one is refused. A source that needs a secret key belongs on the server, marked `"server_only": true`, or in a plugin with a key typed in Settings.
5. **Publish the file before you ship code that needs a new field.** Old apps ignore unknown *fields* but refuse a whole document that has an unknown *value* (a new hole name, a new kind, a higher `schema`). The publish script runs an old-app check for that.
6. **Test against the real service.** The checker cannot know if a mirror is alive, if a GraphQL query is right, or if an episode is the right one. Run the real request by hand before you trust a definition.
7. **You cannot go back to a lower version.** To undo a bad publish, fix the file and publish it with a higher `version`.
8. **When you add or drop a source, update the credits.** `screens.about.catalogues` and `screens.about.subtitles` feed the footer and the privacy page. The website has no list of its own.
9. **Keep the file formatted** (2-space JSON) and keep ids unique and lower case.
10. **Do not mention AI** in commit messages or anywhere else in this repo.

## Decide what kind of change it is

| The user wants | It is | Read |
| --- | --- | --- |
| A new torrent site, a new mirror, a fix to how releases are read | An **indexer** change | `references/format.md` (indexers), `references/recipes.md` |
| A new catalogue, a catalogue that stopped working, new genres or sorts | A **provider** change (and maybe `chains`, `screens`) | `references/format.md` (providers, chains), `references/recipes.md` |
| Anime episodes found by another service's id | A **mapper** | `references/format.md` (mappers) |
| Subtitles from another site | A **subtitle source** | `references/format.md` (subtitles) |
| A new tab, home row, label, genre list or credits | **Screens** | `references/format.md` (screens) |
| Lock out old apps | `min_version` | `references/publishing.md` |
| A user wants their own source, without changing this file | A **plugin** | `references/plugins.md` |
| A source that needs signing, a login or scraping HTML | A **code plugin** (WebAssembly) | `references/plugins.md` |
| A debrid-style service that returns a playable link | A **stream service plugin** | `references/plugins.md` |
| Ranking, episode matching, shapes, id rules, music, TorBox | **Code**, not data | `references/engine.md` |
| It is broken | Debugging | `references/debugging.md` |
| Ship it | Publishing | `references/publishing.md` |

If the request needs something data cannot say, tell the user plainly that it needs a code change in `<code repo>/desktop/core`, and say which module (see `references/engine.md`). Do not bend the JSON to fake it.

## The standard workflow for a change

1. **Read the current entry** you are changing (or the closest existing one to copy). Real entries are the best templates: `nyaa` (RSS), `knaben` (JSON POST), `yts` (nested rows, `empty_when`), `torrentio` (Stremio addon, mapper), `tvmaze` (catalogue), `anilist` (GraphQL), `opensubtitles` (subtitles).
2. **Try the real request first.** For an indexer or provider, run the request with `curl`, look at the real answer, and pick the `rows` path and the field paths from it. Keep a saved copy of a real answer: you will use it as a test fixture.
3. **Make the edit.** Keep the JSON formatted. Keep ids unique. Raise `version`.
4. **Validate the file on its own:**

   ```bash
   cd <code repo>/desktop
   cargo run -p akidev-core --bin akidev-sources -- check "$SOURCES_DIR/sources.json"
   ```

5. **Run the engine's tests with your copy.** The build only downloads `sources.json` when `desktop/sources/sources.json` is missing, so copy your edit there first:

   ```bash
   cp "$SOURCES_DIR/sources.json" <code repo>/desktop/sources/sources.json
   cd <code repo>/desktop && cargo test -p akidev-core
   ```

6. **Add a test for a new indexer or provider** in the code repo, using the real answer you saved. Indexers: `desktop/core/src/indexers/extract.rs` tests (they call `run("<id>", &body, "term")`). Providers: `desktop/core/src/providers/read_tests.rs`. A definition that passes the check does not prove it reads real answers.
7. **Update the credits** in `screens.about` if you added or dropped a source, and the genres in `screens.genres` if a catalogue spells them differently.
8. **Show the user the diff** and say what changes for users.
9. **Only if asked, publish** (see `references/publishing.md`).
10. **Commit** in this repo with a plain message. No attribution lines.

## Quick facts you will need all the time

- Kinds: `anime`, `series`, `movie` (plugins can add more). Shapes: anime = episodes by number, series = season + episode, movie = no episode.
- Indexer holes: `{term}`, `{imdb}`, `{imdb_digits}`, `{imdb_or_term}`, `{season}`, `{episode}`, and `{<mapper id>}` / `{<mapper id>_kind}`.
- Provider holes: `{base}`, `{type}`, `{sort}`, `{id}`, `{term}`, `{page}`, `{per_page}`, `{skip}`, `{genre}`, `{genre_lower}`, `{year}`. A provider `url` must start with `{base}/` (or be exactly `{base}`).
- Subtitle holes: `{imdb}`, `{season}`, `{episode}`, `{term}`, `{year}`.
- JSON body specials: `{"$kind": {...}}`, `{"$sort": {...}}`, `{"$number": "..."}`, `{"$text": "..."}`, and a key ending in `?` is left out when empty.
- Release fields: `title` and `hash` are required; `magnet`, `size`, `file_idx`, `seeders` are optional. A row without a valid 40-hex (or 32 base32) info hash is dropped.
- Cache: parsed answers are cached 10 minutes (60 seconds when empty). Errors are never cached as healthy empty answers.
- Where the live copy is: `https://sources.akidev.live/sources.json` (schema 1) and `https://sources.akidev.live/v2/sources.json` (schema 2).
- Where the code is: `desktop/core/src/definition.rs` (the format), `sources.rs` (the document and its checks), `screens.rs`, `plugin.rs`, `code.rs` (WebAssembly sandbox), `services.rs` (stream services), `indexers/`, `providers/`.

## What to tell the user when you finish

Say, in plain words: what you changed, whether you tested it against the real service, whether the file passes the checker and the tests, what version you set, whether it is published (usually not), and what is left. If something could not be verified (for example a site that was unreachable), say so.
