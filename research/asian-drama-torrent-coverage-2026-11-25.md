# Asian drama torrent coverage research

Date: 2026-11-25

## 1. Decision and scope

This research supports one decision. Akidev needs better release discovery for Korean, Japanese, Chinese, and Thai live-action dramas.

The research covers title search, release search, public torrent APIs, Prowlarr definitions, and episode matching. It does not cover private tracker accounts. It does not publish a source change.

`<code repo>` means the `dishant0406/akidev` repository at commit `588d97d`.

An indexer is a service that lists torrent releases. An API is a direct software interface. RSS is a feed of recent items. Torznab is a standard torrent search feed. An info hash identifies a torrent. Debrid is a paid service that holds a torrent and serves its files.

Claim labels:

- Fact: A primary source, saved response, or code line supports the claim.
- Inference: The facts support the conclusion, but the conclusion is not directly measured.
- Assumption: The claim needs confirmation before use.
- Gap: The available evidence does not answer the question.

## 2. Search plan

- Reproduce title search and release search with fixed Asian drama titles.
- Test public torrent APIs and examine official Prowlarr and Jackett definitions.
- Trace Akidev search terms, alias use, ranking, and file selection.

No tool guarantees full ASD-STE100 compliance. The official dictionary is free at asd-ste100.org.

## 3. Executive findings

Fact: Akidev returned at least one release row for 24 of 25 tested titles. The median successful result count was 10. The test found one HTTP 404 error. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Fact: Torrentio supplied releases for 23 of 24 titles. It supplied 262 of 463 observed release rows. Six titles had only one contributing source.

Fact: The production Prowlarr fallback returned zero rows for five tested titles. They were Crash Landing on You, Itaewon Class, The Gifted, Alice in Borderland, and Shut Up Flower Boy Band.

Fact: The current Prowlarr list contains DMHY, Mikan, and LimeTorrents. DMHY and Mikan are anime sources. Evidence: `<code repo>/scripts/prowlarr-sync.js:11`.

Fact: Cinemeta returned only the English base title for the five fixed dramas. It returned no alternate-title field. Evidence: `research/verification/asian-drama-production-2026-11-25.json` and https://v3-cinemeta.strem.io/manifest.json.

Fact: Akidev searches and ranks releases against that base title. Its alias recovery asks AniList, which covers anime rather than live-action drama. Evidence: `<code repo>/desktop/core/src/stream.rs:653-677` and `725-736`.

Fact: Nyaa live-action RSS returned results for six of seven tested drama titles. It returned one result for Shut Up Flower Boy Band, the title with the HTTP 404 error. The saved test summary records these results. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Fact: The Gifted has a serious title collision. Zilean and TorrentsDB returned the US series for the Thai IMDb ID. Production playback selected a US series pack.

Inference: The main problem is source coverage and title aliases. Basic series support works for the tested titles. Playback works for the two verified Korean examples.

Inference: Nyaa live-action RSS is a useful candidate. Category `4_4` needs a separate entry. Unnumbered batch packs still need a matching change.

Gap: The exact title and app screen that fail for the user remain unknown.

## 4. Production reproduction matrix

Each row records one request to `GET /v1/releases` for season 1 episode 1. Counts describe that request, not permanent availability.

| Country | Title | IMDb | Releases | Contributing sources | Cached | Seeded |
| --- | --- | --- | --- | --- | --- | --- |
| South Korea | Crash Landing on You | tt10850932 | 12 | Torrentio, Zilean, Torrents-CSV | 10 | 5 |
| South Korea | Itaewon Class | tt11239552 | 7 | Torrentio, Zilean, Torrents-CSV | 5 | 6 |
| South Korea | Squid Game | tt10919420 | 96 | Torrentio, Zilean, Torrents-CSV, TorrentsDB | 54 | 46 |
| South Korea | Hotel Del Luna | tt10220588 | 9 | Torrentio, Zilean, Torrents-CSV | 6 | 7 |
| South Korea | Mr. Queen | tt13400006 | 8 | Torrentio, Zilean | 4 | 5 |
| South Korea | Our Beloved Summer | tt15026724 | 14 | Torrentio, Zilean, Torrents-CSV | 8 | 7 |
| South Korea | Moving | tt24640580 | 24 | Torrentio, Zilean, Knaben | 19 | 15 |
| South Korea | Queen of Tears | tt27668559 | 17 | Torrentio, Zilean, Torrents-CSV | 13 | 13 |
| South Korea | Vincenzo | tt13433812 | 21 | Torrentio, Zilean, Knaben, Torrents-CSV | 14 | 13 |
| South Korea | My Name | tt12940504 | 42 | Torrentio, Zilean | 19 | 14 |
| South Korea | D.P. | tt13024974 | 8 | Torrentio | 3 | 8 |
| South Korea | Navillera | tt13885302 | 7 | Torrentio, Zilean | 2 | 4 |
| South Korea | Hometown Cha-Cha-Cha | tt14518756 | 11 | Torrentio, Zilean, Torrents-CSV | 6 | 6 |
| South Korea | Business Proposal | tt14819828 | 11 | Torrentio, Torrents-CSV | 11 | 10 |
| South Korea | My Unfamiliar Family | tt12458252 | 4 | Torrentio | 1 | 4 |
| South Korea | Search: WWW | tt10253244 | 2 | Torrentio | 1 | 2 |
| South Korea | The School Nurse Files | tt12879522 | 5 | Torrentio, Torrents-CSV | 2 | 4 |
| South Korea | Hellbound | tt12235718 | 42 | Torrentio, Zilean, Torrents-CSV | 19 | 22 |
| South Korea | Sweet Home | tt11612120 | 8 | Torrentio | 3 | 6 |
| South Korea | The Greatest Love | tt2304406 | 1 | Torrentio | 1 | 1 |
| South Korea | Reply 1997 | tt2782216 | 1 | Torrentio | 0 | 0 |
| Japan | Alice in Borderland | tt10795658 | 85 | Torrentio, Zilean, Torrents-CSV | 43 | 35 |
| China | The Untamed | tt10554898 | 9 | Torrentio, TorrentsDB, Knaben, Torrents-CSV | 4 | 8 |
| Thailand | The Gifted | tt9136312 | 19 | Zilean, TorrentsDB | 6 | 2 |

Fact: Crash Landing on You and Itaewon Class started playback through the production debrid source. The Gifted also returned an HLS playlist URL, but it selected the US series. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Inference: Playback works for Crash Landing on You and Itaewon Class. The Gifted result shows an identity error.

## 5. Concrete error case

Title: Shut Up Flower Boy Band, IMDb `tt2942950`.

Fact: Production title search returned the series. The detail endpoint returned all 16 episodes.

Fact: Production release search returned HTTP 404. The error was `No matching source found in the providers that answered. Some providers are unavailable; try again shortly.`

Fact: Direct requests from the research host returned these results:

| Source | Result |
| --- | --- |
| Bitsearch | HTTP 200, zero rows |
| Zilean | HTTP 200, zero rows |
| TorrentsDB | HTTP 200, zero rows |
| Knaben | HTTP 503, Web Page Blocked |
| Torrentio | HTTP 503, Web Page Blocked |
| Production Prowlarr | HTTP 200, zero rows |

Fact: Nyaa live-action RSS returned one row for this title. The title was `Shut Up Flower Boy Band (2012) (WEB-DL 1080p h264 AAC-AppleTor)`.

Fact: A temporary Akidev entry for that row still returned zero playable releases. The row did not name a season or episode.

Inference: A public source can identify a release for this exact error. The current source set does not ask that source for live-action drama.

Inference: Akidev also needs to inspect files in an unnumbered batch pack before it can map that pack to episode 1.

Gap: The local HTTP 503 responses describe this research host. They do not prove that Knaben or Torrentio lacks the release.

## 6. Catalog and alias gaps

Fact: Production search found Crash Landing on You, Itaewon Class, and Squid Game by their English titles.

Fact: Production search found Crash Landing on You by `사랑의 불시착` and `Sarangui bulsachak`. It found Squid Game by `오징어 게임` and `Ojing-eo geim`.

Fact: Production search found The Untamed by `陈情令` and `Chen Qing Ling`.

Fact: Production search returned zero rows for the Thai title `เด็กพิเศษ`.

Fact: Native Japanese title search for `今際の国のアリス` returned the 2014 anime before the 2020 live-action series.

Fact: Native Korean title search for `이태원 클라쓰` returned TVmaze ID `series-45540`. English title search returned IMDb ID `series-tt11239552`.

Inference: The same drama can have two Akidev IDs. This can split library state and search behavior.

Fact: TVmaze `/shows/{id}/akas` returns alternate names without an API key. The detail request also accepts `embed[]=akas`. Evidence: https://www.tvmaze.com/api and `research/verification/asian-drama-evidence-2026-11-25/tvmaze-itaewon-embedded.body`.

Fact: Wikidata returns language-specific labels and aliases without an API key. Its data license is CC0. Evidence: https://www.wikidata.org/wiki/Wikidata:Data_access.

Fact: TMDB requires an API key. A request without a key returned HTTP 401. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Inference: TMDB has alternate-title endpoints, but it is not a keyless option.

Inference: TVmaze or Wikidata can supply extra search names. Cinemeta can remain the source for IMDb IDs and episode lists.

Gap: No tested keyless source supplies typed native, romanized, and alternate titles for every drama.

## 7. Current torrent source coverage

Fact: The current series sources are general indexes or IMDb-based aggregators. No current entry is a Korean drama specialist.

| Source | Titles with rows | Release rows |
| --- | --- | --- |
| Torrentio | 23 | 262 |
| Zilean | 15 | 166 |
| Torrents-CSV | 13 | 23 |
| TorrentsDB | 3 | 7 |
| Knaben | 3 | 5 |

Fact: Torrentio, Zilean, and TorrentsDB build series requests from the IMDb ID, season, and episode. They do not search native title text.

Fact: Knaben and Bitsearch search title text. Bitsearch is a fallback source, so normal results prevent its query.

Fact: The Snowfl plugin runs only in the desktop app. The server does not load code plugins.

Inference: A title missing from Torrentio has few alternatives. This explains the single-source titles in the matrix.

Fact: Language does not affect release ranking or file selection. One result list can contain Hindi, Polish, Italian, French-subtitled, and original-language rows.

Inference: A user can see many results and still find no suitable original-language episode.

## 8. Public source candidates

### Nyaa live-action RSS

Fact: Nyaa category `4_1` is Live Action - English-translated. The current Akidev Nyaa entry uses category `1_0` and serves anime only.

Fact: `https://nyaa.net/` returned HTTP 200 for the live-action RSS tests. The feed contains title, info hash, size, seeders, and category.

Fact: The saved Nyaa test summary records these counts. Raw feeds are saved for only three Nyaa responses. The other counts need confirmation.

| Title | Rows |
| --- | --- |
| Crash Landing on You | 2 |
| Itaewon Class | 2 |
| Squid Game | 23 |
| Alice in Borderland | 3 |
| The Untamed | 40 |
| The Gifted | 0 |
| Shut Up Flower Boy Band | 1 |

Fact: The saved episode-term summary records zero rows for the exact term `Crash Landing on You S01E01`. It records one row for each of `Crash Landing on You 01` and `Crash Landing on You S01`. The raw responses are not saved.

Fact: Nyaa category `4_4` contains raw live-action releases. The saved category summary records 17 Itaewon Class rows. It also records one row for each episode from S01E01 to S01E16. The full raw response is not saved.

Fact: A temporary Akidev entry for categories `4_1` and `4_4` added two Itaewon Class releases. One row was `Itaewon Class S01E01 720p HDTV AAC H.265-IXD.mp4`.

Fact: The same temporary entries did not solve Shut Up Flower Boy Band. Its only Nyaa row was an unnumbered batch pack.

Inference: Akidev already sends the `01` and `S01` forms. Separate series entries can use the existing RSS parser.

Inference: Nyaa raw releases help episode search. Unnumbered batch packs still need file inspection or better pack recognition.

Gap: Nyaa returned no Thai drama row for The Gifted. It does not solve every region.

### Direct public source matrix

The public source test recorded 62 attempts. The evidence file contains 54 completed request records. Counts describe one test window. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

| Title | Bitsearch English | Bitsearch native | Zilean | Zilean episode 1 | TorrentsDB relevant | Torrentsome exact | Torrenttip exact |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Crash Landing on You | 4 | 1 | 20 | 0 | 4 | 18 | 18 |
| Itaewon Class | 1 | 0 | 5 | 0 | 4 | 19 | 19 |
| Alice in Borderland | 100 | 0 | 51 | 9 | 31 | Gap | Gap |
| The Untamed | 15 | 0 | 3 | 1 | 11 | Gap | Gap |
| The Gifted, Thai | 100 | 0 | 19 | 6 | 0 | Gap | Gap |

Fact: The Gifted counts from Zilean and TorrentsDB described the US series. None of those rows matched the Thai drama.

Fact: TorrentsDB returned five unrelated Alice in Borderland anime rows. The other 31 rows matched the live-action drama.

Inference: Torrentsome and Torrenttip gave the strongest native Korean episode coverage in this sample. Their current mirror searches returned HTTP 200.

Inference: TorrentsDB gave the strongest accessible episode-level coverage for Japanese and Chinese dramas. Its file indexes support direct episode selection.

Gap: No accessible public service returned an identified Thai The Gifted release.

### Bangumi Moe

Fact: Bangumi Moe has a public JSON API without site credentials. The official Prowlarr definition contains a `Dorama` category.

Fact: The official definition maps `Dorama` to Console rather than TV. A public search for `ドラマ` returned zero rows. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Inference: Correct the category mapping. Before Akidev adds a series entry, test the API filter.

### Tokyo Toshokan

Fact: The public `.se` mirror returned Japanese drama rows and magnet links without a login. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Fact: The live search form uses `type` and `searchName`. The current Prowlarr definition sends `cat` and omits `searchName`. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Fact: The RSS tests returned mixed latest items and ignored the search filters.

Inference: Tokyo Toshokan is a desktop code-plugin candidate. It is not a direct server RSS candidate until filtering works.

### Korean sites with changing public access

Fact: Torrenttip and Torrentsome have public Korean TV categories. Their official definitions include a FlareSolverr warning.

Fact: One test window returned HTTP 403 Cloudflare pages from their main home pages. A later test reached current URLs for public mirror searches and returned HTTP 200. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Fact: The later test returned 18 exact Crash Landing on You rows and 19 exact Itaewon Class rows from each service.

Inference: These sites are strong Korean drama candidates, but their public access and domains are unstable. Before integration, do production-server tests.

Gap: This research did not prove access from the Akidev production address.

## 9. Prowlarr and private index landscape

Fact: The selected Prowlarr and Jackett definitions were byte-for-byte identical at the tested commits. Prowlarr commit: `56b20b19c18fee53869fca2bca72ba59101da2f9`. Jackett commit: `272019ebe9b0287fc1adaa868015831b57902e91`. Evidence: `research/verification/asian-drama-production-2026-11-25.json`.

Fact: Prowlarr and Jackett can expose an indexer through Torznab. The proxy API key is separate from tracker account credentials.

Fact: The official definitions cover these private index groups for Asian drama:

- Japanese and pan-Asian: AsianCinema, AsianDVDClub, JPTV4us.
- Chinese: HDChina, OurBits, CHDBits, HDHome, HDCiTY, TJUPT, PuTao, Audiences, PlayletPT.
- Thai: SiamBIT, TorrentDD, Bitded, Unlimitz.
- Vietnamese: NetHD, VietMediaF.

Fact: These indexes need an account, invitation, application, cookie, password, or API key. Evidence: the compared official definitions and `research/verification/asian-drama-production-2026-11-25.json`.

Inference: They can improve coverage only for users with lawful access. Akidev must not put those credentials in `sources.json`.

Gap: This research did not test private index quality or current registration windows.

## 10. Code behavior and defects

Fact: `Streamer::plan` loads title details and calls `find_releases`. Evidence: `<code repo>/desktop/core/src/stream.rs:251-271`.

Fact: Cinemeta maps only `name` to the title. The card creates one title variant. Evidence: `sources.json:1303-1311` and `<code repo>/desktop/core/src/providers/card.rs:14-19`.

Fact: Series search creates five forms for episode 1. They are `Title S01E01`, `Title 01`, `Title 1`, `Title S01`, and `Title`. Evidence: `<code repo>/desktop/core/src/releases.rs:1171-1189`.

Fact: Unicode normalization preserves native letters. It does not transliterate them. Evidence: `<code repo>/desktop/core/src/releases.rs:1206-1241`.

Fact: Alias recovery asks only the anime catalog. It does not add live-action aliases. Evidence: `<code repo>/desktop/core/src/stream.rs:653-677`.

Fact: Episode parsing supports `SxxExx`, `E`, `EP`, `Episode`, and Chinese `第N话`. It does not support Korean `제N회` or Japanese `第N回`. Evidence: `<code repo>/desktop/core/src/releases.rs:99-109` and `198-223`.

Fact: The identity token list includes Japanese but omits Korean, Chinese, Thai, `dub`, and `sub`. Evidence: `<code repo>/desktop/core/src/releases.rs:578-584`.

Fact: The token list for generic file names has the same omission. Evidence: `<code repo>/desktop/core/src/releases.rs:1510-1520`.

Inference: A title such as `Crash Landing on You Korean S01E01` can fail identity matching when Korean is the first token after the title.

Fact: The server has no title-create route. A correct catalog record does not prove that a torrent release exists. Evidence: `<code repo>/desktop/server/src/api.rs:67-96`.

## 11. Recommendations

1. Add separate Nyaa live-action series entries for categories `4_1` and `4_4`. Add real-response tests for Korean, Japanese, and Chinese titles. Add file inspection for unnumbered batch packs.
2. Add native and romanized title variants. Use TVmaze AKAs or Wikidata labels. Keep Cinemeta as the identifier and episode source.
3. Add Korean, Chinese, and Thai language tokens to identity matching. Add Korean `제N회` and Japanese `第N回` episode patterns.
4. Add country, language, and year evidence to release identity. When the request names the Thai The Gifted, reject the US series.
5. Test Torrentsome and Torrenttip from the production address. Before the test passes, do not assume that their mirrors are stable.
6. Test Bangumi Moe drama search. Before a source change, correct the category.
7. Keep Tokyo Toshokan as a desktop plugin candidate. Before plugin work, correct its search parameters.
8. Offer a user-owned Prowlarr or Jackett plugin for private indexes. Require the user to supply lawful account access.
9. Add a fixed regression set for Asian drama. Include the 24 production titles and the HTTP 404 error case.

Assumption: Nyaa category `4_1` remains stable after the test date.

Assumption: TVmaze AKAs remain useful for most titles. Some titles will still lack a romanized alias.

## 12. Risks and gaps

- Fact: Public torrent availability changes over time. A saved result is not an uptime promise.
- Fact: Cloudflare can block a datacenter host while a home host works.
- Fact: Private tracker definitions do not prove account eligibility or current site health.
- Gap: The research did not measure production p95 latency or HTTP 429 rates for Asian drama searches.
- Gap: The research did not test every episode of every title.
- Gap: The research did not test private trackers.
- Gap: The exact user problem remains unknown until the user supplies the title and app screen.

Do-not-invent list:

- Do not claim that a Prowlarr definition proves current drama coverage.
- Do not claim public access to a private tracker.
- Do not invent native titles or romanizations without a primary source.
- Do not claim that a Cloudflare block affects every host.
- Do not claim that all Korean dramas fail. Most tested titles returned releases.

## 13. Final Step

1. Implement Nyaa live-action categories `4_1` and `4_4`. Add batch-pack file inspection and regression tests.
2. Implement TVmaze or Wikidata title variants.
3. Improve Asian language tokens and episode patterns.
4. Build a private Prowlarr or Jackett plugin for authorized accounts.

## 14. Implementation result

Fact: Source version 49 adds 26 indexers and four providers. It adds Nyaa live-action categories `4_1` and `4_4` as fallback sources. Each source asks once per title and waits five seconds between host requests.

Fact: The code adds TVmaze names, TV database id matching, country and language data, Asian episode forms, country markers, and year-bearing pack inspection. It keeps at most two TVmaze names. It keeps the requested title first.

Fact: Full workspace core tests pass: 443 tests, with four ignored. Core tests pass without default features: 362 tests. Server tests pass: 163 tests. Formatting, Clippy, local release builds, website tests, lint, type checks, and the website build pass.

Fact: The source validator for app `0.1.27` and app `0.1.34` accepts source version 49.

Fact: The final local engine returns five Itaewon Class releases. It returns one Nyaa pack for Shut Up Flower Boy Band. It returns no release for the Thai The Gifted. Evidence: `research/verification/asian-drama-implementation-2026-11-25.json`.

Fact: Production runs app `0.1.35`. Production returns nine Itaewon Class releases and one Nyaa pack for Shut Up Flower Boy Band. It returns no release for the Thai The Gifted. Production plays Itaewon Class through debrid. It refuses the old US Gifted release. Evidence: `research/verification/asian-drama-production-after-2026-11-25.json`.

Fact: macOS and Windows `0.1.35` releases are public. The Homebrew cask points to `0.1.35`.

Gap: The production check covers one request per title. It is not an uptime promise. The Windows installer was not signed because the SignPath API token was absent.

Inference: The HTTP 404 error for Shut Up Flower Boy Band is fixed at release discovery. Playback still needs a live seeder or a debrid copy.

Gap: Nyaa returned HTTP 503 after rapid requests from the research host. Direct access worked again after a cooldown. The final production request for Shut Up Flower Boy Band succeeded.

Gap: Private Asian trackers remain untested because no authorized account was supplied. The exact title and app screen from the first user report remain unknown.

## 15. Sources

Production evidence:

- `research/verification/asian-drama-production-2026-11-25.json`
- `research/verification/asian-drama-production-after-2026-11-25.json`
- `research/verification/asian-drama-implementation-2026-11-25.json`
- `research/verification/asian-drama-evidence-2026-11-25/`
- https://api.akidev.live/v1/search
- https://api.akidev.live/v1/titles/{id}
- https://api.akidev.live/v1/releases?id={id}
- https://api.akidev.live/v1/fallback/search

Catalog sources:

- https://www.tvmaze.com/api
- https://v3-cinemeta.strem.io/manifest.json
- https://www.wikidata.org/w/api.php?action=help&modules=wbsearchentities%7Cwbgetentities
- https://www.wikidata.org/wiki/Property:P1476
- https://developer.themoviedb.org/docs/authentication-application
- https://docs.anilist.co/guide/rate-limiting

Torrent and proxy sources:

- https://github.com/Prowlarr/Indexers/blob/56b20b19c18fee53869fca2bca72ba59101da2f9/README.md
- https://github.com/Jackett/Jackett/blob/272019ebe9b0287fc1adaa868015831b57902e91/README.md
- https://wiki.servarr.com/prowlarr/cardigann-yml-definition
- https://github.com/Prowlarr/Indexers/blob/56b20b19c18fee53869fca2bca72ba59101da2f9/definitions/v11/nyaasi.yml
- https://github.com/Prowlarr/Indexers/blob/56b20b19c18fee53869fca2bca72ba59101da2f9/definitions/v11/bangumi-moe.yml
- https://github.com/Prowlarr/Indexers/blob/56b20b19c18fee53869fca2bca72ba59101da2f9/definitions/v11/tokyotosho.yml
- https://github.com/Prowlarr/Indexers/blob/56b20b19c18fee53869fca2bca72ba59101da2f9/definitions/v11/torrentsome.yml
- https://github.com/Prowlarr/Indexers/blob/56b20b19c18fee53869fca2bca72ba59101da2f9/definitions/v11/torrenttip.yml
- https://bitsearch.eu/api
- https://github.com/iPromKnight/zilean
- https://torrentsdb.com/manifest.json

Akidev sources:

- `<code repo>/desktop/core/src/stream.rs`
- `<code repo>/desktop/core/src/releases.rs`
- `<code repo>/desktop/core/src/providers/card.rs`
- `<code repo>/desktop/sources/sources.json`
- `<code repo>/scripts/prowlarr-sync.js`
- `<code repo>/pipeline/PROWLARR_FALLBACK.md`
