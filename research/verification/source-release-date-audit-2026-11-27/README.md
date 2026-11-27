# Full source release-date audit

Audit date: 2026-11-27

This audit covers every entry in `sources.json` and every plugin in `plugins/`. It tests the live source where the source permits a small public request. It does not test playback or measure uptime.

## What a release date means here

A title release date tells when a movie or series first became public. A torrent upload date, RSS `pubDate`, DVD date, end date, or episode date is not the title release date.

Indexers return release files. Their response fields do not carry title release dates. Akidev must get the date from a provider card. Subtitle sources and stream services also do not provide title release dates.

## Akidev field contract

The current Akidev checkout does not accept `release_date` in `MediaMap`. It also has no `date` expression. The source file now sends both keys for the Akidev work that the owner handles.

The source checker ignores unknown fields. Its pass proves the document shape, not support for the new field or expression.

Required Akidev contract:

```text
MediaMap.release_date: Option<Expression>
Operation.Date { year, month, day }
Media.release_date: Option<String>
```

The value is `YYYY-MM-DD`, `YYYY-MM`, or `YYYY`. `Date` gives `YYYY-MM` with no day and `YYYY` with no month. A missing year or an invalid part gives no value.

`Expression` is an untagged enum. An app that knows `release_date` but not the `date` operation refuses the whole document. A test confirmed it: a `date` object below the known key `year` gave `data did not match any variant of untagged enum Expression`. Ship the field and the operation in the same app release. An app that knows neither ignores the key, so version 52 is safe for the apps in use now.

## Complete source inventory

### Torrent indexers

| Indexer | Kinds | Live sample | Mapped rows | Title release date? | Notes |
| --- | --- | --- | --- | --- | --- |
| `subsplease` | anime | HTTP 200 | 90 downloads | no | `release_date` is the release time, not the series premiere. |
| `nyaa` | anime | HTTP 200 | 75 RSS items | no | `pubDate` is the torrent upload date. |
| `nyaa-live-action` | series | HTTP 200 | 0 items | no | Empty for the Breaking Bad sample. |
| `nyaa-live-action-raw` | series | HTTP 200 | 0 items | no | Empty for the Breaking Bad sample. |
| `animetosho` | anime | HTTP 200 | 5 Torznab items | no | Release feed only. |
| `anibt` | anime | HTTP 200 | 5 Torznab items | no | Release feed only. |
| `tsukihime` | anime | HTTP 200 | 5 JSON rows | no | `source_date` and `added_date` are not title dates. |
| `aniraws` | anime | HTTP 200 | 5 RSS items | no | Release feed only. |
| `tokyotosho` | anime | HTTP 200 | 149 RSS items | no | Release feed only. |
| `knaben` | all three | HTTP 200 | 5 hits | no | No date field in search rows. |
| `torrents-csv` | all three | HTTP 200 | 25 rows | no | No date field in search rows. |
| `aniscraper` | all three | HTTP 504 | not measured | no | One earlier sample returned an empty stream list. Both tested routes then failed. |
| `aniscraper-anirena` | all three | HTTP 504 | not measured | no | Both tested AniScraper routes failed. |
| `torrentio` | all three | HTTP 200 | 0 streams in the direct sample | no | A separate sample returned at least 166 file rows. Results depend on the requested id. |
| `yts` indexer | movie | HTTP 200 | 1 movie | no | The provider card has the year. The indexer row does not. |
| `rss-ftp-eztv` | series | HTTP 200 | 160 items | no | `pubDate` is the feed item date. |
| `rss-ftp-ettv` | series | HTTP 200 | 100 items | no | `pubDate` is the feed item date. |
| `apibay` | all three | HTTP 200 | 100 rows | no | No date field in search rows. |
| `zilean` | series, movie | HTTP 200 | 173 movie rows, 136 series rows | no | No date field in the tested rows. |
| `zilean-anime` | anime | HTTP 200 | 20 rows | no | A `date` field exists, but all tested values were null. |
| `nekobt` | anime | HTTP 200 | 50 rows | no | Some descriptions contain `Aired` and `Premiered` text. This is not a structured title date. |
| `bangumi-moe` | anime | HTTP 200 | 7 rows | no | `publish_time` is a torrent publish time. |
| `torrentsdb` | series, movie | HTTP 200 | 96 streams | no | Stream metadata only. |
| `archive-public-domain` | movie | HTTP 200 | 5 docs | no | The search response has no title release-date field. |
| `bitsearch` | all three | HTTP 200 | 5 results | no | No date field in search rows. |
| `prowlarr` | all three | HTTP 200 | 100 results | no | The fallback response has no title release-date field. |

The Nyaa mirror `https://nyaa.net` also returned HTTP 200 with 75 anime items. It is part of the `nyaa` entry, not a separate indexer.

### Metadata providers and mapper

| Provider | Kinds | Live date field | Precision | Current mapping | Result |
| --- | --- | --- | --- | --- | --- |
| `anilist` | anime | `startDate.year`, `startDate.month`, `startDate.day`, then `seasonYear` | full date, year and month, or year | `coalesce` of `date`, `startDate.year`, `seasonYear` | correct source mapping, needs Akidev support |
| `cinemeta` | series, movie | `released`, then `releaseInfo` | full date or year. Search rows: year only | `regex` for the date part of `released`, then `year` of `releaseInfo` | correct |
| `tvmaze` | series | `premiered` | full date or null | direct path | correct |
| `yts` | movie | `year` | year only | direct path | correct, full date impossible from this API |
| Kitsu mapper provider | anime | `videos.0.released`, then `releaseInfo` | full date or year | `regex` for the date part of `videos.0.released`, then `year` of `releaseInfo` | first video is the best available title date. It is a UTC time, so it can be one day early |

Live examples:

- AniList `143103`: `2026-11-20`.
- Cinemeta `tt0903747`: `2008-01-20`.
- Cinemeta `tt0111161`: `1994-10-14`.
- TVMaze `169`: `2008-01-20`.
- YTS `316`: `2013`. `date_uploaded` is `2015-10-31 21:36:29` and is not used.
- Kitsu `kitsu:45666`: `2026-11-20`, from the first video, with `releaseInfo` `2026` as the fallback.

### Subtitle source

| Source | Kinds | Live sample | Title release date? | Notes |
| --- | --- | --- | --- | --- |
| `opensubtitles` | all three | HTTP 200, 37 subtitles | no | Subtitle labels can contain a release year. They are not a title date source. |

### Plugins

| Plugin | Type | Live or file check | Title release date? | Notes |
| --- | --- | --- | --- | --- |
| `snowfl` | torrent indexer module | Module SHA-256 matches manifest. Direct homepage request returned HTTP 520. | no | A separate live sample returned 40 upstream rows. Its response used `name` and magnet links, while the plugin maps `title` and `hash`. The module was not run again because its source crate is absent. |
| `torbox` | stream service module | Module SHA-256 matches manifest | no | A debrid service resolves a selected release. It does not supply title metadata. |

## Corrections made in the source document

1. Every provider card has `release_date`.
2. The Kitsu mapper provider card has `release_date`.
3. AniList list, search, detail, related, and recommended selections request all three `startDate` parts.
4. The source version is `52`.
5. The skill docs define the field, the `date` expression, and the source-specific limits.

No indexer, subtitle source, or plugin received a fake date field. Their response contracts do not contain title release dates.

## Limits

- One live sample does not prove uptime.
- A timeout or HTTP 504 does not prove that a service is offline.
- An empty result can be correct for the requested title or id.
- The current Akidev checkout ignores the new field and expression.
- YTS cannot provide a full release date from its current API.
- The Snowfl module was not run because its source crate and a compatible test harness are absent.

## Second check on 2026-11-28

- The AniList, Cinemeta, and Kitsu mappings were corrected. See `../release-date-fields-2026-11-27/README.md` for the faults and the live values.
- `zilean-anime` was asked again. Its rows have `date: null` and `year: 0`. They describe the file, not the title.
- `torrentio` returned 500 streams for `tt0111161`. A stream has `name`, `title`, `infoHash`, `fileIdx`, and `behaviorHints`. It has no date.
- The source checker passed: `version 52: 26 indexers, 4 providers`. Run it from the code repo root: `cargo run -q -p akidev-core --bin akidev-sources -- check <path>`. The script `check-source.sh` looks for `desktop/core`, which the code repo no longer has.
- No provider sends a home release date or a release date for one country. A film that is only in cinemas has a past `release_date` and no source.
- Both `aniscraper` routes returned HTTP 200 with `{"streams":[]}` for `tt0111161` and `kitsu:7442`. No row was available to read. The route is a Stremio stream route, and that format has no title date.
- The templates `mapper.json` and `plugin-catalogue-kind.json` now have `release_date` in the card.

## Every catalogue path, 2026-11-28

One `card` reads the rows of every path of a provider. Each path was asked live, and the corrected mapping was applied to its rows.

| Provider | Path | Rows | Full date | Year only | No date |
| --- | --- | --- | --- | --- | --- |
| AniList | list, sort `popularity` | 50 | 50 | 0 | 0 |
| AniList | list, sort `trending` | 50 | 50 | 0 | 0 |
| AniList | list, sort `score` | 50 | 50 | 0 | 0 |
| AniList | detail `16498`, related | 10 | 10 | 0 | 0 |
| AniList | detail `16498`, recommended | 12 | 12 | 0 | 0 |
| Cinemeta | list `movie/top` | 50 | 47 | 3 | 0 |
| Cinemeta | list `movie/imdbRating` | 49 | 47 | 2 | 0 |
| Cinemeta | list `movie/year` | 50 | 33 | 17 | 0 |
| Cinemeta | list `series/top` | 50 | 45 | 5 | 0 |
| Cinemeta | list `series/imdbRating` | 50 | 44 | 6 | 0 |
| Cinemeta | list `series/year` | 50 | 38 | 12 | 0 |
| Cinemeta | search | 7 | 0 | 6 | 1 |
| TVMaze | list `schedule/full` | 5159 | 5159 | 0 | 0 |
| TVMaze | search, detail | 11 | 11 | 0 | 0 |
| YTS | list | 50 | 0 | 50 | 0 |
| YTS | search `dune` | 16 | 0 | 16 | 0 |
| YTS | detail `316`, suggestions | 5 | 0 | 5 | 0 |

The list paths hide most upcoming titles before the card is read. Cinemeta has a `drop` rule with `after_today`. TVMaze has a `drop` rule with `after_today` and 30 grace days. The AniList `recent` sort asks for no `NOT_YET_RELEASED` titles. Search and detail paths do not hide them. Thus an upcoming title usually comes from search, with the precision that the search row has.
