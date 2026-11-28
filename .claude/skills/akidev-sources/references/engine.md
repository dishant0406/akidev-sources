# What is code, not data

Some things cannot be changed by editing `sources.json`. They are engine behaviour in the code repo, and changing them needs a code change and a new build. If the user asks for one of these, say so plainly and name the module. Do not try to fake it in the JSON.

Where: `<code repo>` (`crates/core/` is the shared engine, `apps/server/` the website's backend, `apps/desktop/` the desktop app, `crates/tv-ffi/` the TV bridge).

## Contents

1. What is code
2. How a search runs (so you know what the data feeds)
3. How playing works (so you know where sources fit)
4. Where each thing lives

---

## 1. What is code

| Thing | Where | Why it is not data |
| --- | --- | --- |
| Ranking, filtering and file matching (title, year, season, episode; samples and extras; HEVC and AV1 as "extra"; seeders order) | `crates/core/src/releases.rs`, `crates/core/src/stream.rs` | It decides what is the *right* release. The JSON only says where to look. |
| The three shapes (`anime`, `series`, `movie`) and the id rules (`anime-16498`, `series-tt0903747-s1e5`, qualified `kind-provider~id`) | `crates/core/src/model.rs`, `crates/core/src/media_id.rs` | They decide how episodes are keyed, listed and played. |
| How an episode's file is picked inside a torrent or a debrid listing | `crates/core/src/releases.rs` (`pick_for_identity` and friends) | Safety: a wrong pick plays the wrong episode. |
| Music (YouTube Music and Audius) | `crates/core/src/music.rs`, `crates/core/src/audius.rs` | Written as code. Their addresses are fixed there. A new music source needs code. |
| The server's stream sources: TorBox (debrid), the torrent engine, the Internet Archive | `apps/server/src/sources/`, `apps/server/src/play.rs` | They hold secrets and run ffmpeg and torrents. |
| The server's Prowlarr route and its keys | `apps/server/src/api.rs`, `apps/server/src/fallback.rs`, server settings | Secrets cannot be in a public file. The `prowlarr` indexer entry in the JSON only says where to ask. |
| Limits, slots, rate limits, HLS and transcode policy | `apps/server/src/limits.rs`, `apps/server/src/hls.rs`, `apps/server/src/config.rs` | Server safety. |
| Signing keys, the feed address, the update source, usage reports | `crates/core/src/sources.rs` (`FEED_URL`, `PUBLIC_KEY`), `crates/core/src/update.rs`, `apps/desktop/src/analytics.rs` | Fixed on purpose. |
| Watch party's server address | `apps/desktop/src/party.rs` | Fixed in the app. |

Everything about **which** catalogues, torrent sites and subtitle sites exist, how to ask them and read them, the screens, the credits and the trackers *is* data.

## 2. How a search runs

**Title search** (finding "Breaking Bad" in the catalogues): one search per kind with a tab, at once. Each kind follows its **chain**: the first provider answers, the next answers on empty or failure. The lists are interleaved round-robin; title matches are preferred. It fails only if every kind failed. On the website this is `GET /v1/search`; in the app the same code runs in-process and shows each kind as it arrives. Plugin catalogues are searched too, each with a 6 second limit.

**Release search** (finding a torrent, the "plan"): `Streamer::plan(id)` parses the id, fetches the title's detail (names, year, IMDb id), builds terms (the title and other names), adds the IMDb id and, for anime, a mapped id (only for the exact same episode), then asks every indexer that serves the kind (the desktop app skips `server_only` ones). Each indexer's `fanout` decides how many requests. Mirrors are tried in order. Answers are read with the indexer's own `response`, trackers are added, rows are filtered and ranked, and a fallback indexer is asked if nothing worthwhile came back. Slower indexers keep running and their rows are merged in later. If nothing is found and the title is not anime, other names from the anime catalogue are tried.

## 3. How playing works

- **Website:** the browser sends `POST /v1/play`. The server shares one search per episode, takes a slot, plans, orders releases, and tries its sources in the order of `STREAM_SOURCES` (debrid, torrent, archive-org), each with a share of the time. It delivers a direct file when the browser can play it, otherwise HLS through ffmpeg. The answer is a link on `stream.akidev.live`.
- **Desktop app:** the app plans locally. Enabled stream services (plugins) are asked first, for the best 4 releases. Otherwise the local torrent engine races the best candidates, picks the file, and serves it on `127.0.0.1` with a secret token. libmpv plays it.

## 4. Where each thing lives

| Area | Files |
| --- | --- |
| The data format | `crates/core/src/definition.rs` |
| The document, checks, loading | `crates/core/src/sources.rs` |
| Screens, home rows and their style (`HomeRow`, `RowStyle`: `ranked` is a Top 10, cut to ten by `RowStyle::trim`) | `crates/core/src/screens.rs` |
| Plugins | `crates/core/src/plugin.rs`, `crates/core/src/code.rs`, `crates/core/src/services.rs` |
| Indexers | `crates/core/src/indexers/` |
| Catalogues | `crates/core/src/providers/` |
| Search across kinds | `crates/core/src/search.rs` |
| Subtitles | `crates/core/src/subtitles.rs` |
| Plans and resolving | `crates/core/src/stream.rs`, `crates/core/src/torrent.rs`, `crates/core/src/serve.rs` |
| Server routes (the home row's style and its cut to ten: `apps/server/src/dto.rs`, `RowOut::of`) | `apps/server/src/api.rs` |
| Server play and sources | `apps/server/src/play.rs`, `apps/server/src/sources/` |
| Desktop screens, settings, player (the Top 10 number: `apps/desktop/src/row.rs`) | `apps/desktop/src/` |
| TV: the bridge and the screens (the Top 10 card: `RankedCard`, `HomeScreen.kt`) | `crates/tv-ffi/src/lib.rs`, `apps/tv-android/app/src/main/kotlin/live/akidev/tv/` |
| Website rows (the Top 10 number: `row.tsx`) | `apps/web/src/components/` |
| Notes | `pipeline/`, `docs/design.md`, `docs/flow.md` |
