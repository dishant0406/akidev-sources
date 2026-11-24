import argparse
import datetime
import json
import math
import statistics
import time
import urllib.error
import urllib.parse
import urllib.request


def get_json(url, body=None, headers=None):
    request_headers = dict(headers or {})
    request_headers.setdefault(
        "User-Agent", "Akidev/0.1.34 (+https://akidev.live)"
    )
    if body is not None:
        request_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode(),
        headers=request_headers,
        method="GET" if body is None else "POST",
    )
    with urllib.request.urlopen(request, timeout=150) as response:
        return json.load(response)


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[math.ceil(len(ordered) * fraction) - 1]


def probe_fallback(base):
    health = get_json(f"{base}/health").get("fallback", {})
    searches = []
    queries = [
        ("Sintel", {"q": "Sintel", "kind": "movie"}),
        ("Frieren", {"q": "Frieren", "kind": "anime", "episode": 1}),
        (
            "Breaking Bad",
            {"q": "Breaking Bad", "kind": "series", "season": 1, "episode": 5},
        ),
    ]
    for query, params in queries:
        url = f"{base}/v1/fallback/search?{urllib.parse.urlencode(params)}"
        started = time.perf_counter()
        results = get_json(url, headers={"x-akidev-fallback": "1"})["results"]
        seconds = time.perf_counter() - started
        sources = {}
        for result in results:
            source = result.get("source", "unknown")
            sources[source] = sources.get(source, 0) + 1
        searches.append(
            {
                "query": query,
                **{key: value for key, value in params.items() if key != "q"},
                "http_status": 200,
                "seconds": round(seconds, 6),
                "results": len(results),
                "sources": sources,
            }
        )
    return {
        "checked_at": datetime.date.today().isoformat(),
        "health": health,
        "searches": searches,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:9187")
    parser.add_argument("--requests", type=int, default=6)
    parser.add_argument("--play-id")
    parser.add_argument("--fallback-only", action="store_true")
    args = parser.parse_args()
    if not args.fallback_only and args.requests < 2:
        parser.error("--requests must be at least 2")
    if args.fallback_only and args.play_id:
        parser.error("--play-id cannot be used with --fallback-only")

    output = {}
    if not args.fallback_only:
        latency = {}
        unique_selection_ids = {}
        for media_id in [
            "anime-16498-ep1",
            "movie-tt0111161",
            "series-tt0903747-s1e5",
            "movie-tt1727587",
        ]:
            times = []
            releases = []
            for _ in range(args.requests):
                started = time.perf_counter()
                releases = get_json(f"{args.base}/v1/releases?id={media_id}")["releases"]
                times.append((time.perf_counter() - started) * 1000)
            warm = sorted(times[1:])
            latency[media_id] = {
                "cold_ms": round(times[0], 1),
                "p50_ms": round(statistics.median(times), 1),
                "p95_ms": round(percentile(times, 0.95), 1),
                "warm_p50_ms": round(statistics.median(warm), 1),
                "warm_p95_ms": round(percentile(warm, 0.95), 1),
            }
            unique_selection_ids[media_id] = len(
                {release["id"] for release in releases if release.get("id")}
            )
        output = {
            "latency": latency,
            "unique_selection_ids": unique_selection_ids,
        }

        if args.play_id:
            play = get_json(f"{args.base}/v1/play", {"id": args.play_id})
            if play.get("available") and play.get("url"):
                url = play["url"]
                if url.startswith("/"):
                    url = args.base + url
                request = urllib.request.Request(
                    url, headers={"Range": "bytes=0-1023"}
                )
                with urllib.request.urlopen(request, timeout=45) as response:
                    play["byte_probe"] = {
                        "status": response.status,
                        "content_type": response.headers.get("Content-Type"),
                        "bytes": len(response.read(1024)),
                    }
            output["play"] = play

    if args.fallback_only:
        output["production_fallback"] = probe_fallback(args.base)

    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        raise SystemExit(f"HTTP {error.code}: {error.read().decode()}") from error
