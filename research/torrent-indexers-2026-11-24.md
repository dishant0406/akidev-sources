# Torrent indexer research for Akidev

Research date: 2026-11-24

## Result

Akidev can add several useful sources without an account or a secret key. Bitsearch gives the strongest new general coverage. AniBT, Tsukihime, and Aniraws give useful anime coverage. RSS-FTP can replace the unreachable EZTV API. Internet Archive gives a legal public-domain movie source.

The largest server gap is Prowlarr. Its current deployment uses only DMHY, Mikan, and LimeTorrents. A controlled Prowlarr expansion can add broad coverage, but it needs production-server tests and strict latency limits.

Public Comet and MediaFusion instances return useful torrent metadata. Their public terms do not permit automated bulk use. Akidev must use a permitted self-hosted instance or obtain permission before it adds these services.

Implementation status: The local source document uses version 48 at this time. It has 24 indexers. It adds seven direct sources. It removes the unreachable EZTV API.

It adds the Nyaa.net mirror and upgrades Knaben to v2. The server fallback filters by media kind. The Snowfl desktop plugin is also integrated. No source document is published.

AniRena is a fallback because two live samples returned no rows. The YTS mirror stayed after a live request redirected to the current site and returned a valid movie.

Direct sources enforce request budgets. AniBT waits one second between requests. Knaben waits two seconds. Aniraws waits one second as a conservative limit. Bitsearch stops after 200 process-local requests per UTC day. Parser tests use saved real-response fixtures.

## Scope and method

An indexer is a service that returns torrent releases. A direct indexer is a source that Akidev calls without Prowlarr. An info hash is the content identifier of a torrent. A seeder is a peer that has the entire torrent.

An API is an application programming interface. RSS is a machine-readable release feed. Torznab is an XML search format for torrent indexes. A Stremio addon is a service that returns media streams to Stremio.

A DHT is a distributed hash table that stores peer contact data. A debrid service fetches a torrent and returns a direct media link. A code plugin is a desktop WebAssembly module that can make requests and parse pages. A server resolver is server code that fetches `.torrent` files and computes their info hashes.

The research used official documentation, official source code, public pages, and live public requests. It used no account, password, API key, CAPTCHA solution, or protection bypass. A CAPTCHA is a test that separates people from programs.

Each service received a small number of requests. A timeout means that the research network received no answer within the stated limit. It does not prove that the service is offline. One live sample does not measure uptime.

## Akidev baseline

The local `sources.json` used schema 1 and version 44 at the start of the research. The live document used version 46. Both documents contained the same 18 indexers and the same indexer request definitions. The implementation started from the live document. The daily tracker job raised the live version to 47 before publication. The local version is 48.

At the start of the research, the list had 14 anime indexers, 10 series indexers, and 10 movie indexers. These counts included the server-only Prowlarr fallback.

Akidev accepts JSON or RSS answers. Each release needs a title and a valid info hash. The info hash can use 40 hexadecimal characters or 32 base32 characters. A row without a supported hash is removed.

The source document permits 64 indexers. One search plans at most 96 requests. The process permits 24 HTTP exchanges at once. The default normal search limit is four seconds. The default fallback limit is 15 seconds.

Akidev caches a useful answer for 10 minutes. It caches an empty answer for 60 seconds. It does not cache an HTTP error as a healthy empty answer.

The desktop app skips `server_only` indexers. The Prowlarr entry is both `server_only` and `fallback`. It helps the website server, but it does not help the desktop app.

Evidence:

- `sources.json:38-868`
- `README.md:291-428`
- `README.md:597-607`
- `README.md:1404-1433`
- `desktop/core/src/config.rs:61-70`
- `desktop/core/src/indexers/mod.rs:133-188`

## Current source health

The audit made one request to each current indexer. It then corrected two malformed requests and checked the EZTV mirrors. Fourteen indexers returned useful rows with valid info hashes.

| Source | Live result | Assessment |
| --- | --- | --- |
| SubsPlease | 90 downloads with valid base32 hashes | Useful |
| Nyaa | 75 RSS items with valid hashes | Useful |
| AnimeTosho | 100 Torznab items with valid hashes | Useful |
| Tokyo Toshokan | 149 RSS items with valid hashes | Useful |
| Knaben v1 | 50 JSON rows with valid hashes | Useful |
| Torrents-CSV | 25 JSON rows with valid hashes | Useful |
| AniScraper | Empty `streams` array for the sample movie | Weak in this sample |
| AniScraper AniRena | Empty `streams` array for the sample movie | Weak in this sample |
| Torrentio | 500 rows with valid hashes | Useful |
| YTS | One movie with three valid torrent hashes | Useful |
| EZTV | All three configured hosts timed out | Broken in this audit |
| APIBay | 100 JSON rows with valid hashes | Useful |
| Zilean | 200 JSON rows with valid hashes | Useful |
| Zilean anime | 20 JSON rows with valid hashes | Useful |
| NekoBT | 50 JSON rows with valid hashes | Useful |
| Bangumi.moe | Seven JSON rows with valid hashes | Useful |
| TorrentsDB | 116 rows, with 85 rows after deduplication | Useful |
| Prowlarr fallback | 100 anime rows, no Breaking Bad rows, one unrelated music row for Inception | Useful for anime, weak for general media |

The Prowlarr anime sample contained 66 DMHY rows and 34 Mikan rows. The Inception sample contained one DMHY music row. At audit time, the fallback sent no media category filter. This added irrelevant results.

The audit used live public requests. It saved temporary evidence outside the repository.

## Ranked direct additions

| Priority | Source | Kinds | Live evidence | Main limit | Decision |
| --- | --- | --- | --- | --- | --- |
| 1 | Bitsearch | Anime, series, movie | 100 valid movie hashes | 200 requests per day per IP without a key | Add as a fallback or use a server key |
| 2 | AniBT | Anime | Nine valid Torznab rows | No seeder count | Add |
| 3 | Tsukihime | Anime | Ten valid JSON rows | No seeder count in search | Add |
| 4 | Aniraws | Anime | Valid Torznab and RSS rows | Rate-limit behavior needs confirmation | Add after a limit decision |
| 5 | RSS-FTP EZTV | Series | 160 current RSS items | Recent releases only, no seeder count | Replace the failed EZTV API |
| 6 | RSS-FTP ETTV | Series | 100 current RSS items | Recent releases only, high duplication | Add as a recent-TV fallback |
| 7 | Internet Archive public domain | Movie | 11 valid `btih` rows for the sample title | Legal scope varies by item | Add with a strict rights filter |
| 8 | Nyaa.net | Anime | 75 valid RSS items | Mostly duplicates Nyaa.si | Add as a mirror |
| 9 | Knaben v2 | Anime, series, movie | Ten valid JSON rows | Official status reports a temporary two-second request limit | Upgrade after a load test |

All nine candidate definitions passed Akidev's source checker. The checker proves the data shape, not service quality.

### 1. Bitsearch

Request:

```text
GET https://bitsearch.eu/api/v1/search
  ?q={term}
  &category={kind_category}
  &sort=seeders
  &order=desc
  &page=1
  &limit=100
```

Category values are `4` for anime, `3` for series, and `2` for movies.

Read `results`. Use `title`, `infohash`, `size`, and `seeders`. Keep `must_contain_term: true`.

The official API permits 200 requests per day per IP without a key. A free account key raises the limit to 1,000 requests per day. A secret key cannot go in `sources.json`.

The live Shawshank sample returned 100 valid hashes. A comparison with seven tested sources found 25 duplicate hashes and 75 unique hashes. The comparison included Torrentio, Zilean, MediaFusion, Comet, Knaben, Torrents-CSV, and YTS. It did not include APIBay or TorrentsDB because those samples were not available.

Use Bitsearch as a fallback until Akidev has a safe request budget. A normal direct source can consume the free daily limit on a shared server address.

Sources:

- https://bitsearch.eu/api
- https://bitsearch.eu/content-removal


### 2. AniBT

Request:

```text
GET https://anibt.net/torznab/api
  ?t=search
  &q={term}
  &cat=5070
  &limit=100
  &offset=0
```

Read RSS items. Use `title`, `torznab:attr@infohash`, and `torznab:attr@size`. Leave `seeders` absent when the feed omits it.

AniBT needs no account or API key. Its official limit is 60 requests per 60 seconds per IP. The official docs support automated use through Torznab. The robots file does not disallow `/torznab/api`.

The live sample returned nine valid rows. Four hashes also appeared in Nyaa.si. All nine appeared in the DMHY sample, but Akidev does not use DMHY as a direct source.

AniBT matches only a trailing two-to-four-digit episode number. It does not understand `EP05` or Chinese episode notation. Keep Akidev's title and episode checks.

Sources:

- https://wiki.anibt.net/en/docs/open-api/torznab
- https://wiki.anibt.net/en/docs/open-api/limits
- https://anibt.net/robots.txt


### 3. Tsukihime

Request:

```text
GET https://api.tsukihime.org/v1/search/torrents
  ?q={term}
  &limit=100
  &offset=0
```

Read `results`. Use `name`, `btih`, and `totalsize`. Keep `must_contain_term: true`. Leave `seeders` absent.

The OpenAPI document defines no authentication scheme. The query needs at least two characters. The live Bleach sample returned ten rows and ten valid hashes.

A detail request can return tracker seeder counts. Akidev's data format cannot make one detail request per result. Omit the seeder count unless Akidev adds a server adapter.

Sources:

- https://api.tsukihime.org/openapi.json
- https://github.com/dominc8/qbittorrent-tsukihime-search-plugin


### 4. Aniraws

Torznab request:

```text
GET https://aniraws.org/api
  ?t=search
  &q={term}
  &cat=5070
  &limit=200
  &offset=0
```

Use `title`, `torznab:attr@infohash`, `torznab:attr@size`, `torznab:attr@magneturl`, and `torznab:attr@seeders`.

RSS request:

```text
GET https://aniraws.org/rss2
  ?q={term}
  &cat=5070
  &limit=200
  &offset=0
```

Use `title`. Read the hash from `guid` with `btih:([0-9a-f]{40})`. Read the size from `description` with `Total size: ([0-9]+) bytes`. The RSS answer has no seeder count.

The official FAQ describes public read-only endpoints with no API key. The live Torznab answer contained valid hashes, sizes, magnets, and seeder counts. The live RSS answer contained valid `urn:btih:` identifiers.

The Torznab answer also contained `newznab:apilimits` with `apimax="1"`. The official FAQ does not explain this value. Determine the limit before Akidev uses Torznab as a normal source. The RSS candidate passed the source checker.

Sources:

- https://aniraws.org/api-faq
- https://aniraws.org/robots.txt


### 5. RSS-FTP EZTV

Request:

```text
GET https://rss.ftp.sh/eztv-1080p-x265-rss.xml
```

Use `fanout: per-title`. Keep `must_contain_term: true`. Read the hash and magnet from `link`.

The live feed contained 160 items. Each sampled item had a valid info hash. The feed has no query parameter and no seeder count. It lists recent releases only.

RSS-FTP says that it checks feeds every 10 minutes. It states a 20-minute expiration. This source can replace the failed EZTV API for recent episodes. It cannot find older episodes by IMDb id.

Source:

- https://rss.ftp.sh/


### 6. RSS-FTP ETTV

Request:

```text
GET https://rss.ftp.sh/ettv-rss.xml
```

Use the same RSS mapping as RSS-FTP EZTV. The live feed contained 100 items with valid magnet links.

The feed combines ETTV and The Pirate Bay results. Expect duplicate hashes. Its main value is recent TV coverage after the EZTV error.


### 7. Internet Archive public domain

Request:

```text
GET https://archive.org/advancedsearch.php
  ?q=mediatype:movies AND licenseurl:*publicdomain* AND btih:* AND title:("{term}")
  &fl=identifier,title,btih,licenseurl,item_size
  &rows=50
  &page=1
  &output=json
```

Read `response.docs`. Use `title`, `btih`, and `item_size`. Leave `seeders` absent. Keep `must_contain_term: true`.

The comma-separated `fl` parameter works. Akidev does not need repeated `fl[]` parameters.

The live Duck and Cover sample returned 11 items with valid `btih` values. A fetched `.torrent` file produced the same info hash as the search row.

Keep the `licenseurl:*publicdomain*` filter in every request. Internet Archive does not guarantee the rights status of uploaded items. The filter reduces risk, but it does not prove that every item is legal to share in every country.

Sources:

- https://archive.org/advancedsearch.php
- https://help.archive.org/help/rights
- https://help.archive.org/help/prelinger-archive


### 8. Nyaa.net mirror

Add `https://nyaa.net` to the existing Nyaa host list after a fixture test. Do not create a new indexer.

The live feed returned 75 valid hashes. A same-time comparison with Nyaa.si found 61 shared hashes, 14 Nyaa.si-only hashes, and 14 Nyaa.net-only hashes. The mirror can improve resilience, but it does not give full new coverage.

Sources:

- https://nyaa.net/
- https://nyaa.net/rss

### 9. Knaben v2 upgrade

Request:

```text
GET https://api.knaben.org/v2/search
  ?q={term}
  &sf=title
  &c={kind_categories}
  &o=seeders
  &d=desc
  &s=50
  &f=0
```

Category values are `6000000` for anime, `2000000` for series, and `3000000,2000000` for movies.

Read `hits`. Use `title`, `hash`, `bytes`, and `seeders`. Use `seeders`, not `liveSeeders`.

The official v2 API uses GET requests and supports edge caching. The live sample returned ten valid rows. The current v1 POST source also returned valid rows, so this upgrade is not urgent.

The official status page reports a temporary one-request-per-two-seconds limit after high API traffic. Do a load test before Akidev changes the current entry.

Sources:

- https://knaben.org/api/v2/
- https://knaben.org/status


## Prowlarr expansion

Prowlarr is an indexer manager. It can query many torrent sites through one API. Akidev's server asks Prowlarr only after the normal sources fail.

The deployment sync uses this static list:

```text
dmhy
mikan
limetorrents
```

The sync removes every other Prowlarr indexer. It adds missing entries, but it does not re-enable an existing disabled entry. A Prowlarr error can leave the live enabled list at less than the static list.

Evidence:

- `scripts/prowlarr-sync.js:10-15`
- `scripts/prowlarr-sync.js:33-62`
- `pipeline/PROWLARR_FALLBACK.md:40-46`

The server sends no indexer ID, category, or media kind to Prowlarr. It permits two searches at once. It gives Prowlarr nine seconds and the full fallback 13 seconds. It follows at most four download links to recover missing hashes. It returns at most 100 results.

Evidence:

- `desktop/server/src/fallback.rs:23-39`
- `desktop/server/src/fallback.rs:231-303`
- `desktop/server/src/api.rs:477-532`

### Public candidates for a production test

Evaluate these public sites in small batches:

- RuTor
- Torrent9
- MegaPeer
- NewStudio
- NoNaMe Club
- TorrentGalaxy
- Torlock
- YourBittorrent
- TorrentFunk
- Bitsearch
- AniBT
- AniDex
- ACG.RIP
- Shana Project

Do not add a site because Prowlarr has a definition. A definition does not prove access from Akidev's server. It does not prove a direct info hash. It does not grant permission to use the site.

AniBT and Bitsearch have direct APIs. Prefer those direct entries. Use Prowlarr for sites that expose only HTML or require server-side request handling.

Do not re-add the current blocked list without new evidence:

- 1337x
- Kickass mirrors
- ExtraTorrent
- TorrentKitty
- UIndex
- TorrentDownload
- TorrentProject

The deployment notes report Cloudflare challenges from the server address. A previous challenge solver timed out on every fallback search. Do not add a protection bypass.

### Required server changes

Add the media kind to the fallback request. Send the kind to Prowlarr as a category filter. Remove non-video rows before Akidev ranks them.

Add selective indexer groups. For example, use a fast general group, an anime group, and a slow fallback group. Do not search every enabled indexer for every request.

Measure the p95 search time after each batch. Stop a batch if it causes timeouts, HTTP 429 responses, or irrelevant results. Keep sites that return a direct info hash or magnet link. Defer sites that need a `.torrent` download for every row.

## Stremio aggregators

A Stremio addon can return torrent metadata with `infoHash`. It can also return a direct-play URL from a debrid service. Akidev can use only the torrent metadata rows.

### MediaFusion

Public Midnight endpoints:

```text
https://mediafusionfortheweebs.midnightignite.me/manifest.json
https://mediafusionfortheweebs.midnightignite.me/stream/movie/{imdb}.json
https://mediafusionfortheweebs.midnightignite.me/stream/series/{imdb}:{season}:{episode}.json
```

Read `streams`. Use `behaviorHints.filename`, `infoHash`, `fileIdx`, and `behaviorHints.videoSize`. Remove rows that contain only `url`.

The live Shawshank sample returned 25 valid hashes. Ten hashes did not appear in the combined Torrentio and Zilean sample. All 25 hashes appeared in the Comet sample.

The public manifest accepts IMDb, TMDB, TVDB, MAL, and MediaFusion IDs. It does not list Kitsu. Use MediaFusion for series and movies unless Akidev adds a Kitsu-to-MAL mapper.

The public instance has no uptime promise. ElfHosted states that automated bulk use of its public instances is not permitted. MediaFusion's README also limits the project to educational and personal use. Use a permitted self-hosted instance for production.

Sources:

- https://github.com/mhdzumair/MediaFusion
- https://docs.elfhosted.com/legal/public-instances


### Comet

Public developer endpoints:

```text
https://comet.feels.legal/manifest.json
https://comet.feels.legal/stream/movie/{imdb}.json
https://comet.feels.legal/stream/series/{imdb}:{season}:{episode}.json
```

Use the same field mapping as MediaFusion. Keep `fileIdx` because Comet often selects one file inside a pack.

The live Shawshank sample returned 1,087 valid hashes. It included 352 file indexes. A comparison with seven tested sources found 502 duplicate hashes and 585 unique hashes. This comparison has the same limits as the Bitsearch comparison.

Comet gives large incremental coverage, but its default public answer is too large for a normal direct source. Configure a small result limit per resolution. Filter sources that duplicate Torrentio, Zilean, and other existing pools.

The manifest lists Kitsu, but the stream handler accepts only movie and series media types. Anime use needs a separate mapping test.

The same public-instance terms apply. Use a permitted self-hosted instance. Do not add the public developer URL to the global source document without permission.

Sources:

- https://github.com/g0ldyy/comet
- https://docs.elfhosted.com/legal/public-instances


### StremThru Torz

StremThru Torz can return P2P torrent metadata. It can also return store-backed direct links. Use only rows that keep `infoHash`.

The tested public Torznab route returned HTTP 403. The public manifest required configuration. Do not add the public endpoint. Evaluate a permitted P2P configuration on a self-hosted instance.

Source:

- https://github.com/MunifTanjim/stremthru
- https://docs.stremthru.13377001.xyz/stremio-addons/torz

### Jackettio and AIOStreams

Jackettio duplicates the Prowlarr fallback. Useful private indexes need the user's own Jackett configuration and credentials.

AIOStreams queries other addons and built-in sources. Its public instance disables P2P output. It adds another request layer and mostly returns duplicate data.

Do not add these services as direct Akidev sources.

## Code plugins and server adapters

### Snowfl

Snowfl aggregates several public indexes. It needs a public client key from its JavaScript bundle. The key changes at runtime. A static `sources.json` entry cannot do this flow.

The live sample returned 125 rows with valid magnet hashes. A desktop code plugin can make the two bootstrap requests and parse the JSON answer. A server adapter can give the same coverage to the website.

Do not publish a captured client key. The module must read the current key at runtime. Make at most eight requests per call, as Akidev's sandbox requires.

Source:

- https://github.com/ChocoTonic/snowfl

### Bitmagnet and Rats Search

Bitmagnet and Rats Search are self-hosted DHT search services. They can find trackerless torrents and releases absent from public websites. No official public instance was verified.

A private Akidev backend can expose either service through a server-only indexer. This adds long-tail coverage, but it needs operational work. DHT seeder counts are rough estimates. A new DHT index needs time to grow.

Do not expose Bitmagnet directly to the public internet. Its project warns that the API has destructive actions and lacks a security review.

Sources:

- https://bitmagnet.io/
- https://github.com/bitmagnet-io/bitmagnet
- https://github.com/librats/rats-search/blob/master/docs/API.md

### Blender Open Movies and PublicDomainTorrents

Blender Open Movies publishes RSS feeds with `.torrent` URLs. PublicDomainTorrents publishes RSS and HTML pages with `.torrent` URLs. Neither feed gives a direct info hash.

A server resolver can fetch a `.torrent` file and compute its hash. A desktop code plugin can do the same work for a small catalog. These sources give legal or clearer-license coverage, but they add little mainstream coverage.

Sources:

- https://video.blender.org/feeds/videos.xml?videoChannelId=9
- https://studio.blender.org/terms-and-conditions
- https://publicdomaintorrents.info/bt/rss.php

## Sources on hold

| Source | Reason | Next action |
| --- | --- | --- |
| DMHY RSS | The robots file disallows `/topics/rss/` | Obtain permission before direct use |
| Anime Garden API | The robots file disallows `/api/` | Obtain permission before direct use |
| Mikan RSS | The feed needs a Bangumi subject ID | Add a Bangumi mapper before use |
| AniDex | The tested hosts refused connections | Monitor |
| Shana Project | The feed has `.torrent` links but no full info hash | Use a resolver or omit |
| HorribleSubs | The project shut down in 2020 | Omit |
| Erai-raws | The feed needs a token and login cookie | Use Prowlarr only with an authorized account |
| ACG.RIP | The XML feed has `.torrent` links but no info hash | Use a resolver or omit |
| TheRARBG | The official JSON API timed out | Retest from the Akidev server |
| Torlock | The official Torznab API timed out | Retest from the Akidev server |
| TorrentFunk | The official JSON API timed out | Retest from the Akidev server |
| YourBittorrent | The official JSON API timed out | Retest from the Akidev server |
| SolidTorrents | It uses the Bitsearch product and API at this time | Use `bitsearch.eu` once |
| 1337x | Cloudflare and IP blocks | Keep excluded |
| TorrentGalaxy | Checkpoint or CAPTCHA reports | Use only if a normal public request succeeds |
| LimeTorrents | HTML search and download-link redirects | Keep in Prowlarr |
| GloDLS | HTML search | Consider a code plugin only after a live request |
| MagnetDL | Unstable reachability | Monitor |
| BTDig | HTML search and no seeder count | Low-priority fallback only |
| Original RARBG | The service closed in 2023 | Omit |
| Yggtorrent | The original service closed after a March 2026 hack | Omit |
| iDope | The old domain serves unrelated content | Omit |
| 037hd | The tested domain serves gambling content | Omit |
| Torrent Paradise | The old domain serves gambling content, and the current API has a Cloudflare challenge | Omit |
| Magnetz | The live API returned HTTP 401 | Omit until a key model exists |
| TorrentClaw | The live API returned a Cloudflare HTTP 403 | Omit |
| Academic Torrents | The content is research data, not films or series | Omit from media search |
| OpenTorrent | The domain is parked, and the active project is a client | Omit |

Sources for status decisions:

- https://share.dmhy.org/robots.txt
- https://animes.garden/robots.txt
- https://therarbg.to/developers/
- https://www.torlock.com/apis.html
- https://www.torrentfunk.com/apis.html
- https://yourbittorrent.com/api.html
- https://bitsearch.eu/api
- https://torrentfreak.com/iconic-torrent-site-rarbg-shuts-down-all-content-releases-stop-230531
- https://torrentfreak.com/yggtorrent-shuts-down-after-hack-leak-and-stolen-crypto

## Private trackers

Prowlarr and Jackett support many private trackers. These include HD, scene, regional, classic-film, and specialist anime indexes. They can give high-quality releases, but they need an authorized account.

Do not add a private tracker without the operator's permission. Keep credentials in Prowlarr or another secret store. Never put a credential in `sources.json`. A supported definition does not grant access.

Private trackers also need a separate rule review. Some forbid automated downloading or public proxying. A server-only source does not remove this duty.

## Main risks

### Legal and terms risk

A public API does not grant permission to download or share copyrighted media. A valid info hash does not prove the title, episode, safety, or legal status of a torrent. Apply the user's local law and each site's terms.

The Internet Archive rights filter reduces risk. It does not replace a rights review. Public Comet and MediaFusion instances do not permit automated bulk use. Use a permitted self-hosted instance.

### Reliability risk

Public mirrors and APIs change often. A domain can expire, change owner, or serve unrelated content. Use official domain lists and primary documentation. Do not trust a mirror from a search-result list alone.

A timeout does not prove a block. A successful sample does not prove uptime. Track errors and latency after every release.

### Rate-limit risk

Bitsearch permits 200 requests per day per IP without a key. AniBT permits 60 requests per minute. Knaben reports a temporary two-second limit. Aniraws publishes an unexplained `apimax="1"` value.

Use fallback mode, response caching, and a server key where permitted. Stop requests after HTTP 429. Obey `Retry-After`.

### Result-quality risk

Aggregators can return the wrong title, a bonus file, a sample, or the wrong episode. Keep Akidev's title, year, season, episode, and filename checks. Do not use a direct-play URL as torrent metadata.

DHT results can contain dead or false hashes. Historical datasets have no current availability guarantee. Seeder counts are observations from one source at one time.

### Performance risk

More sources increase request count, duplicate rows, and search latency. Comet returned 1,087 rows for one movie. Akidev keeps at most 512 rows from one request. Use configured result caps and selective source groups.

### Secret risk

An API key, passkey, cookie, or configured Stremio manifest path can act as a credential. Never put one in `sources.json`, a report, a log, or a public repository. Use server settings or the user's private plugin configuration.

## Implementation plan

### Phase 1: repair the current baseline

1. Replace the failed EZTV API with RSS-FTP EZTV after fixture tests.
2. Add RSS-FTP ETTV as a recent-TV fallback.
3. Add Nyaa.net as a mirror of the existing Nyaa source.
4. Add media-kind and category filters to the Prowlarr fallback.
5. Monitor the two empty AniScraper routes before removal.

### Phase 2: add direct sources

1. Add AniBT and Tsukihime.
2. Add Aniraws after a rate-limit decision.
3. Add the filtered Internet Archive public-domain source.
4. Add Bitsearch as a fallback or with a server-side key.
5. Upgrade Knaben to v2 after a load test.

### Phase 3: expand server coverage

1. Do a production-server test of three public Prowlarr candidates.
2. Measure latency, unique hashes, HTTP errors, and irrelevant rows.
3. Add the next batch only if the first batch passes.
4. Prefer indexers that return a direct hash or magnet.
5. Defer slow download-link resolvers.

### Phase 4: evaluate advanced sources

1. Deploy a permitted self-hosted MediaFusion instance.
2. Configure a small Comet result cap on a permitted instance.
3. Build a Snowfl server adapter or desktop code plugin.
4. Evaluate Bitmagnet or Rats Search as a private DHT backend.
5. Add Blender or PublicDomainTorrents only if the legal catalog justifies a resolver.

### Required tests for every source

1. Save a real response as a fixture.
2. Add a parser test in `desktop/core/src/indexers/extract.rs`.
3. Do the source checker test.
4. Do a real search through `scripts/try-local.sh`.
5. Do the core test suite.
6. Measure unique hashes and playback success on a fixed title set.
7. Publish only after the user gives approval.

Commands:

```bash
.claude/skills/akidev-sources/scripts/check-source.sh path/to/source.json
.claude/skills/akidev-sources/scripts/try-local.sh path/to/sources.json series-tt0903747-s1e5 movie-tt0111161
```

Do the core tests in the `desktop` directory of the code repo:

```bash
cargo test -p akidev-core
```

## Success measures

Measure these values before and after each phase:

- Unique valid hashes per title.
- Playable releases per title.
- Successful playback starts.
- Wrong-episode selections.
- Duplicate-hash ratio.
- Search latency at p50 and p95.
- HTTP errors and HTTP 429 responses.
- Cache hit rate.
- Contribution from each source.
- Fallback use rate.

Use a fixed set of anime, series, and movie titles. Include new releases, old releases, non-English titles, and titles with several remakes.

## Implementation verification

The local source document passed the source checker with version 48 and 24 indexers. The Snowfl plugin passed the plugin checker with its module hash. The Snowfl module also passed a live sandbox search.

The core test suite passed 422 tests with code plugins enabled. The server test suite passed 163 tests. The Snowfl module passed five unit tests. Clippy passed for the core, server, and Snowfl module. The release server and desktop app builds passed.

Two local-swarm tests run one at a time. This prevents their large transfers from competing during the full suite. The full core suite passed after this change.

The real engine returned Aniraws and Tsukihime releases for an anime title. A fallback-only engine run returned 48 Bitsearch releases for a movie title.

Knaben v2 made repeated requests without HTTP 429 in the real engine run. Aniraws uses RSS2 because the Torznab limit value is unclear.

The live engine command used these title IDs:

```bash
.claude/skills/akidev-sources/scripts/try-local.sh sources.json anime-16498-ep1 movie-tt0111161 series-tt0903747-s1e5
```

It returned 34 anime releases, 150 movie releases, and 48 series releases. Aniraws supplied 21 anime releases. Tsukihime supplied four anime releases. Knaben supplied 30 movie releases and one series release.

A second engine run used a temporary document with only Bitsearch. It returned 48 movie releases. The module command used a live Snowfl search for `sintel`. It returned valid info hashes, sizes, and seeder counts.

These runs measured release discovery and local playback. They did not measure p95 latency on the production server.

Production fallback tests returned HTTP 200 for all three queries. Sintel returned two DMHY rows in 1.22 seconds. Frieren episode 1 returned 100 rows in 4.81 seconds. Breaking Bad S01E05 returned no rows in 1.82 seconds. Production health still reports one failing Prowlarr indexer.

Local measurements used six requests per title against the release server. Cold p95 includes the first request. Warm p95 excludes it.

| Title | Cold p95 | Warm p50 | Warm p95 |
| --- | --- | --- | --- |
| Attack on Titan episode 1 | 6385.0 ms | 185.0 ms | 5360.3 ms |
| The Shawshank Redemption | 2758.5 ms | 15.9 ms | 16.6 ms |
| Breaking Bad S01E05 | 5052.4 ms | 11.8 ms | 4851.2 ms |
| Sintel | 5494.7 ms | 1.5 ms | 2.8 ms |

A separate local run returned 95 unique anime selections, 215 unique movie selections, 85 unique series selections, and 27 unique Sintel selections.

The local server started Sintel playback from a torrent. A range request returned HTTP 206, `video/mp4`, and 1024 bytes.

The committed measurement script is `research/verification/measure-releases.py`. The saved summary is `research/verification/results-2026-11-24.json`.

Run the production fallback probe with:

```bash
python3 research/verification/measure-releases.py --base https://api.akidev.live --fallback-only
```

## Candidate validation status

The temporary candidate definitions passed the source checker. The final direct definitions are in `sources.json`. Comet and MediaFusion passed schema checks but are not integrated because public terms do not permit automated bulk use.

A source checker pass does not approve a service's terms. It does not prove uptime. It does not replace a real parser test or a playback test.

The Snowfl plugin passed the plugin checker with its module. The module passed a live sandbox search against Snowfl.

## Primary references

### Akidev

- https://sources.akidev.live/sources.json
- `sources.json`
- `README.md`
- `<code repo>/scripts/prowlarr-sync.js`
- `<code repo>/desktop/server/src/fallback.rs`
- `<code repo>/pipeline/PROWLARR_FALLBACK.md`

### Torznab and indexer managers

- https://torznab.github.io/spec-1.3-draft/torznab/Specification-v1.3.html
- https://newznab.readthedocs.io/en/latest/misc/api.html
- https://wiki.servarr.com/prowlarr/supported-indexers
- https://github.com/Prowlarr/Indexers/tree/master/definitions/v11
- https://github.com/Jackett/Jackett/wiki/Definition-format

### Direct sources

- https://bitsearch.eu/api
- https://wiki.anibt.net/en/docs/open-api/torznab
- https://aniraws.org/api-faq
- https://api.tsukihime.org/openapi.json
- https://rss.ftp.sh/
- https://archive.org/advancedsearch.php
- https://nyaa.net/rss
- https://knaben.org/api/v2/

### Aggregators and DHT

- https://github.com/mhdzumair/MediaFusion
- https://github.com/g0ldyy/comet
- https://github.com/MunifTanjim/stremthru
- https://github.com/ChocoTonic/snowfl
- https://bitmagnet.io/
- https://github.com/librats/rats-search/blob/master/docs/API.md
- https://docs.elfhosted.com/legal/public-instances

### Legal and rights references

- https://help.archive.org/help/rights
- https://help.archive.org/help/prelinger-archive
- https://studio.blender.org/terms-and-conditions
- https://www.copyright.gov/help/faq/faq-fairuse.html

No tool guarantees ASD-STE100 compliance. Full compliance needs the official dictionary at https://asd-ste100.org/.
