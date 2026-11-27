---
name: akidev-sources
description: "Write, change, test, debug and publish anything about Akidev's sources: give it a website, an API or a plugin idea and it writes the complete JSON (an indexer for a torrent site, a provider for a catalogue, a subtitle source, a mapper, screens, or a whole plugin, including WebAssembly code and stream services), then validates and tests it. Covers sources.json (indexers, providers, chains, mappers, subtitles, screens, trackers, min_version), plugins, the signing and publishing flow, how the website, server and desktop app read the sources, and what data can and cannot do."
---

# Akidev sources

You are working in the `akidev-sources` repo, or on something that reads it. This skill is the full guide: the format, the recipes, the plugin rules, the publishing flow and the debugging steps. Read the references for the details. This file is the map and the rules.

## What this repo is

- It holds `sources.json`, `README.md`, optional plugins, and research tools. It contains no secrets.
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
11. **Every provider card sends its release date.** Use `release_date`. Send `YYYY-MM-DD` when the API has a full date. Send `YYYY-MM` when it has a year and a month. Send `YYYY` when it has only a year. Never invent a month or day. Never send a timestamp or a year range.

## Release dates

A release date tells when a movie or series first became public. It is not the upload date, DVD date, end date, or episode date.

Every provider must send `release_date` in its `card`. The mapper provider must also send it. Add the field to list, search, detail, related, and recommended rows because the same card reads all of them.

Indexers, subtitle sources, and stream services do not send title release dates. Do not add a date field to their response mappings. Do not use torrent upload times or RSS `pubDate` values as title dates.

Run this coverage check after a source change:

```bash
jq -e '
  (.providers | length > 0)
  and ([.providers[].card | has("release_date")] | all)
  and ([.mappers[]?.provider.card | has("release_date")] | all)
' sources.json
```

Use `coalesce` when a provider has a full date and a year fallback. Use the `date` expression when a provider splits the date into fields. Use `regex` to cut the date part from a timestamp. Use `year` to cut the first year from a range such as `2008–2013`. A provider with only a year sends that year.

A release date in the past does not mean that a source exists. A film can be in cinemas for months before a home release. No current provider sends a home release date or a release date for one country.

Current sources:

| Provider | Mapping | Full date? |
| --- | --- | --- |
| AniList | `date` over `startDate.year`, `startDate.month`, `startDate.day`, then `startDate.year`, then `seasonYear` | often. Of 200 upcoming titles on 2026-11-28, 28 had a full date, 32 a year and month, 44 a year, 96 no date |
| Cinemeta | `regex` over `released` for the `YYYY-MM-DD` part, then `year` over `releaseInfo` | list and detail rows often. Search rows have the year only |
| TVMaze | `premiered` | yes, when known |
| YTS | `year` | no, year only |
| Kitsu mapper | `regex` over `videos.0.released` for the `YYYY-MM-DD` part, then `year` over `releaseInfo` | often, with a year fallback |

For AniList, request `startDate { year month day }` in every query. Include it in related and recommended rows too. Never use `nextAiringEpisode.airingAt` as the title date.

See `research/verification/release-date-fields-2026-11-27/README.md` for provider field research. See `research/verification/source-release-date-audit-2026-11-27/README.md` for the full source inventory and live audit.

## Decide what kind of change it is

| The user wants | It is | Read |
| --- | --- | --- |
| **"Add this website / API / feed"**, or "write me a plugin for X" | The whole job: investigate, write, test, deliver | **`references/from-a-website.md`** (start here) |
| A new torrent site, a new mirror, a fix to how releases are read | An **indexer** change | `references/format.md` (indexers), `references/recipes.md` |
| A new catalogue, a catalogue that stopped working, new genres or sorts | A **provider** change (and maybe `chains`, `screens`) | `references/format.md` (providers, chains), `references/recipes.md` |
| A release date is missing, wrong, or only a year | A **provider** change | `references/format.md` (`release_date`), `references/recipes.md` (release dates) |
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

## When the user gives you a website, an API or an idea

This is the main job. **Read `references/from-a-website.md` and follow it.** In short:

1. **Investigate** the site with `curl` (save the answers): is it JSON, RSS, Torznab, a Stremio addon, GraphQL, or only HTML? Find the search request and look at one real row. If it shows a challenge page, a captcha or a login wall, stop and tell the user. Never get around protections.
2. **Decide** what to build: an indexer, a provider, a subtitle source, a mapper, a code plugin (HTML only, signing, a login) or a stream service plugin (a debrid-style service). Decide where it goes: `sources.json` (for everyone, the user publishes) or a plugin (for one user, desktop only).
3. **Write it from a template** in `templates/` (indexers for JSON, POST, RSS, Torznab and Stremio; providers for REST and GraphQL; subtitles; mappers; plugins; and two code modules). Do not write from nothing.
4. **Test it** with the scripts, all of them:
   - `scripts/check-source.sh <file>`: the real rules, for a whole document, one entry, or a plugin (with its module).
   - `jq` on your saved real answer: every path gives a value.
   - `scripts/try-local.sh <sources.json> <title ids>`: a real local server and a real release search; shows how many releases each source found.
   - `scripts/build-plugin.sh <crate> <plugin.json> <out>` and `scripts/try-module.sh <module.wasm> <export> '<input>' <hosts>`: build a code plugin, hash it, and run it against the real site.
5. **Deliver it**: the JSON (and `.wasm`), where it goes, how to install it (a plugin: the app's plugins folder, or host it side by side and add a link in Settings), and **publish only if the user asks**.
6. **Report** what you built, what you tested, and what you could not verify.

Never put a key in `sources.json`, never ask for a password in chat, and never echo a key the user gives you.

## The standard workflow for a change

1. **Read the current entry** you are changing (or the closest existing one to copy). Real entries are the best templates: `nyaa` (RSS), `knaben` (JSON GET), `yts` (nested rows, `empty_when`), `torrentio` (Stremio addon, mapper), `tvmaze` (catalogue), `anilist` (GraphQL), `opensubtitles` (subtitles).
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

## Files in this skill

- `references/from-a-website.md`: the playbook from a website to a finished source (read this first for any "add this site").
- `references/format.md`, `recipes.md`, `plugins.md`, `publishing.md`, `debugging.md`, `engine.md`: the details.
- `templates/`: ready-to-edit entries and two code modules (all pass the real checker).
- `scripts/`: `check-source.sh`, `try-local.sh`, `build-plugin.sh`, `try-module.sh`. They need the code repo (`CODE_REPO`, or `../akidev` next to this repo).

## What to tell the user when you finish

Say, in plain words: what you changed, whether you tested it against the real service, whether the file passes the checker and the tests, what version you set, whether it is published (usually not), and what is left. If something could not be verified (for example a site that was unreachable), say so.
