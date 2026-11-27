# Release-date fields in the configured providers

Research date: 2026-11-27

This note records the fields that each configured provider uses for `card.release_date`. A release date tells when a movie or series first became public. It is not an upload date, DVD date, end date, or episode date.

## Result

| Provider | Source field | Mapping in `sources.json` | Date precision |
| --- | --- | --- | --- |
| AniList | `startDate.year`, `startDate.month`, `startDate.day`, then `seasonYear` | `coalesce` of the `date` expression, `startDate.year`, `seasonYear` | Full date, year and month, or year |
| Cinemeta | `released`, then `releaseInfo` | `regex` for the date part of `released`, then `year` of `releaseInfo` | Full date or year |
| TVMaze | `premiered` | direct path | Full date or no date |
| YTS | `year` | direct path | Year only |
| Kitsu mapper provider | `videos.0.released`, then `releaseInfo` | `regex` for the date part of `videos.0.released`, then `year` of `releaseInfo` | Full date or year |

Every provider card and the mapper provider card now has `release_date`. No provider can give more precision than its API contains. YTS has no full release-date field.

## AniList

Primary reference: https://docs.anilist.co/reference/object/media

`Media.startDate` is the first official release date. Its type is `FuzzyDate`. The year, month, and day are each optional integers.

Primary reference: https://docs.anilist.co/reference/object/fuzzydate

Live request:

```sh
curl -sS -X POST 'https://graphql.anilist.co' \
  -H 'content-type: application/json' \
  --data-binary '{"query":"query($id:Int){Media(id:$id,type:ANIME){id title{english romaji} format status season seasonYear startDate{year month day} nextAiringEpisode{episode airingAt}}}","variables":{"id":143103}}'
```

Live result for `anime-143103`:

```json
{
  "id": 143103,
  "title": {
    "english": "Witch on the Holy Night",
    "romaji": "Mahoutsukai no Yoru"
  },
  "format": "MOVIE",
  "status": "FINISHED",
  "season": "FALL",
  "seasonYear": 2026,
  "startDate": {
    "year": 2026,
    "month": 11,
    "day": 20
  },
  "nextAiringEpisode": null
}
```

The `date` expression returns `2026-11-20`. It pads month and day to two digits. With no day it returns `YYYY-MM`. With no month it returns `YYYY`.

`seasonYear` is not a full date. Do not use it to invent a month or day. `nextAiringEpisode.airingAt` is an episode time, not the title release date.

The list, search, and detail queries now request `startDate { year month day }`. The related and recommended selections request the same fields.

## Cinemeta

Primary references:

- https://raw.githubusercontent.com/Stremio/stremio-addon-sdk/master/docs/api/responses/meta.md
- https://raw.githubusercontent.com/Stremio/stremio-core/master/src/types/resource/meta_item.rs

`meta.released` is an optional ISO 8601 timestamp. `meta.releaseInfo` is a year or a series year range. Catalog search rows often omit `released`, so `releaseInfo` is the fallback.

Live series request:

```sh
curl -sS 'https://v3-cinemeta.strem.io/meta/series/tt0903747.json'
```

Relevant result:

```json
{
  "released": "2008-01-20T00:00:00.000Z",
  "year": "2008–2013",
  "releaseInfo": "2008–2013"
}
```

Live movie request:

```sh
curl -sS 'https://v3-cinemeta.strem.io/meta/movie/tt0111161.json'
```

Relevant result:

```json
{
  "released": "1994-10-14T00:00:00.000Z",
  "year": "1994",
  "releaseInfo": "1994",
  "dvdRelease": "2008-08-15T00:00:00.000Z"
}
```

`dvdRelease` is not the title release date. The episode `released` and `firstAired` fields are not the series title date.

Search request:

```sh
curl -sS 'https://v3-cinemeta.strem.io/catalog/movie/top/search=Witch%20on%20the%20Holy%20Night.json'
```

Relevant row:

```json
{
  "id": "tt31970593",
  "type": "movie",
  "name": "Witch on the Holy Night",
  "releaseInfo": "2026"
}
```

This row gives only the year. Some rows omit all date fields. The mapping cuts the `YYYY-MM-DD` part from `released` with `regex`. It cuts the first year from `releaseInfo` with `year`, so `2008–2013` gives `2008`.

## TVMaze

Primary reference: https://api.tvmaze.com

Show search and show detail responses use `premiered`. It is a `YYYY-MM-DD` string or null. Schedule rows hold the show below `show` or `_embedded.show`, so the same card mapping reads them.

Live request:

```sh
curl -sS 'https://api.tvmaze.com/shows/169'
```

Relevant result:

```json
{
  "id": 169,
  "name": "Breaking Bad",
  "type": "Scripted",
  "status": "Ended",
  "premiered": "2008-01-20",
  "ended": "2019-10-11",
  "averageRuntime": 60,
  "weight": 100,
  "genres": ["Drama", "Crime", "Thriller"]
}
```

`premiered` gives `2008-01-20`. `ended` is not the title release date. A null `premiered` gives no release date.

## YTS

Primary endpoint: https://movies-api.accel.li/api/v2

The list and detail responses contain `year`. They also contain `date_uploaded`, which is an upload time, not a release date. The API has no full release-date field.

Live list request:

```sh
curl -sS 'https://movies-api.accel.li/api/v2/list_movies.json?limit=1&sort_by=date_added&order_by=desc'
```

Relevant row:

```json
{
  "id": 80106,
  "title": "On the Last Day of Christmas",
  "title_english": "On the Last Day of Christmas",
  "year": 2026,
  "date_uploaded": "2026-11-27 14:07:14"
}
```

Live detail request:

```sh
curl -sS 'https://movies-api.accel.li/api/v2/movie_details.json?movie_id=316&with_cast=true&with_images=true'
```

Relevant result:

```json
{
  "id": 316,
  "title": "Assassins Run",
  "title_english": "Assassins Run",
  "year": 2013,
  "date_uploaded": "2015-10-31 21:36:29",
  "runtime": 88
}
```

The YTS mapping sends `2013` or `2026`. It does not use `date_uploaded`.

## Kitsu mapper provider

Live request:

```sh
curl -sS 'https://anime-kitsu.strem.fun/meta/anime/anilist:143103.json'
```

Relevant result:

```json
{
  "id": "kitsu:45666",
  "kitsu_id": "45666",
  "name": "Mahoutsukai no Yoru",
  "type": "movie",
  "releaseInfo": "2026",
  "released": null,
  "videos": [
    {
      "id": "kitsu:45666",
      "released": "2026-11-20T00:00:00.000Z",
      "season": 1,
      "episode": 1
    }
  ]
}
```

The title object has no full date. Its only video has the film date. The mapper uses `videos.0.released`, then `releaseInfo`. For a series, this is also the first episode date. That is the best title date this provider exposes.

## Checks to repeat

1. Request one title from each provider.
2. Read each field named in the mapping.
3. Make sure that the result is a full date, a year, or no value.
4. Make sure that no mapping uses an upload date, DVD date, end date, or later episode date.
5. Run the source checker after every change.

## Corrections on 2026-11-28

A second live check found three faults in the first mappings. All three are corrected in `sources.json`.

1. AniList partial dates. Of 200 upcoming titles (`status: NOT_YET_RELEASED`, by popularity), 28 had a full date, 32 had a year and month, 44 had a year only, and 96 had no date. The first mapping gave nothing for the 76 partial dates. The mapping now falls back to `startDate.year`, then `seasonYear`.
2. Cinemeta sent a timestamp (`2008-01-20T00:00:00.000Z`) or a year range (`2008–2013`). Neither is in the `YYYY-MM-DD`, `YYYY-MM`, `YYYY` contract. The mapping now cuts both.
3. The Kitsu mapper had the same timestamp fault. Its mapping now cuts the date part too.

Values that the corrected mappings give on live answers:

| Provider | Title | Value |
| --- | --- | --- |
| AniList | `143103` Witch on the Holy Night | `2026-11-20` |
| AniList | first page of upcoming titles | `2027`, `2027-10`, `2027-01-09`; 22 of 50 had no date |
| Cinemeta detail | `tt0111161` | `1994-10-14` |
| Cinemeta detail | `tt0903747` | `2008-01-20` |
| Cinemeta detail | `tt31970593` Witch on the Holy Night | `2026` (`released` is null) |
| Cinemeta list | `catalog/series/top` | full date on 45 rows, year only on 5 rows |
| Cinemeta search | `breaking bad` | year only on 6 rows, no date on 1 row |
| Kitsu | `anilist:143103` | `2026-11-20` |
| Kitsu | `anilist:21` One Piece | `1999-10-20` |
| TVMaze | `169` | `2008-01-20` |
| YTS | newest movie | `2026` |

The `date` rows assume that the Akidev `date` expression gives `YYYY-MM` with no day. The first note said that a missing part gives no value. The `coalesce` in `sources.json` is correct with both behaviours. With the strict behaviour a year-and-month title sends only the year.

## The title that started this work

Witch on the Holy Night (AniList `143103`) opened in Japanese cinemas on 2026-11-20. AniList gives `status: FINISHED` and `startDate` 2026-11-20. Its release in other countries is a cinema release in January 2027. No configured provider sends that date. AniList, Cinemeta, Kitsu, TVMaze, and YTS have no field for a release in one country or for a home release.

Thus `release_date` for this title is a past date, and the title still has no source. The field cannot mark this title as not yet available. A cinema-only film needs a different signal, such as "no source found and released less than some months ago".

## Kitsu dates can be one day early

The Kitsu `released` value is a UTC time. A late-night show in Japan starts on the day before in UTC. Attack on Titan (AniList `16498`) gives `2013-04-06` from Kitsu and `2013-04-07` from AniList. One Piece and Frieren gave the same day from both. Use the AniList date when both exist. The Kitsu card is only the mapper card.
