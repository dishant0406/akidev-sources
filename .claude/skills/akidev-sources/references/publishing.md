# Publishing

Publishing changes what every user's app and the server do within hours. **Do it only when the user asks.** Editing, validating and testing are free.

## Contents

1. How a change travels
2. Before you publish: the checklist
3. Publish
4. The live copy can be ahead of this repo
5. The two feeds, and the old-app check
6. The daily tracker job
7. Forcing old apps to update
8. Rolling back
9. Rollout order when code and data change together
10. One-time setup (already done)

---

## 1. How a change travels

1. You edit `sources.json` in this repo and raise `version`.
2. `publish-sources.sh` (in the code repo) checks the file, checks old apps would accept it, signs it with the private key, and uploads it to a Cloudflare R2 bucket, shown at `sources.akidev.live`.
3. It is published **twice** with one version number:
   - the root, `https://sources.akidev.live/sources.json`, schema 1, which every app reads;
   - `/v2`, `https://sources.akidev.live/v2/sources.json`, the same document with `"schema": 2`, which newer builds read first.
4. Every app and the server asks at start and about every 6 hours.
5. A downloaded copy is used only if its signature is valid (checked with the public key baked into the code), its `version` is higher than the one in use (the same version with a higher schema also wins), and it passes the same checks as the built-in copy. Otherwise the app keeps what it has.

The website reads the screens through the server (`GET /v1/screens`), so it picks up screens changes when the server picks up the document.

## 2. Before you publish: the checklist

- [ ] The user asked for a publish (or said the change should go live).
- [ ] `version` is higher than the live one (see section 4).
- [ ] `check` passes on the file.
- [ ] `cargo test -p akidev-core` passes with your copy in `desktop/sources/sources.json`.
- [ ] You tried the real request for anything new, and kept a fixture test for it.
- [ ] `screens.about` names every catalogue and subtitle source that is in the file.
- [ ] If the file uses a new field or value that only newer code understands, the code that reads it is already released (or you are about to release it: see section 9).
- [ ] You know which release is the oldest you still support (`OLD_REF`).
- [ ] The `cf` CLI is logged in and the signing key exists (`.secrets/sources.key` in the code repo's `desktop/`, or `KEY=`).
- [ ] You have said, in plain words, what will change for users.

## 3. Publish

From `<code repo>/desktop`:

```bash
OLD_REF=desktop-mac-v0.1.27 SOURCES_DIR=<path to akidev-sources> ./scripts/publish-sources.sh
```

What the script does, in order:

1. Refuses a file whose `version` is not higher than the live one.
2. Runs `scripts/check-old-apps.sh` on it: builds the validator of the oldest release you named (`OLD_REF`) and of the newest mac release, and checks the document with each.
3. Makes the schema 2 copy (`sources-v2.json` from `SOURCES_DIR` if there is one, otherwise the same document with `"schema": 2`). The two must have the same `version`.
4. Signs both and checks the signatures.
5. Uploads `/v2` first, then the root (so a build that knows the newer feed never sees the older one ahead of it).

Settings (environment variables): `SOURCES_DIR` (required), `OLD_REF` or `OLD_REFS` (which old releases to check), `BUCKET` (default `akidev-sources`), `KEY` (default `.secrets/sources.key`), `URL` (default `https://sources.akidev.live`).

Check afterwards:

```bash
curl -s https://sources.akidev.live/sources.json | jq '[.version, .schema]'
curl -s https://sources.akidev.live/v2/sources.json | jq '[.version, .schema]'
```

Both should show the new version, with schema 1 and 2.

## 4. The live copy can be ahead of this repo

The daily tracker job raises the live `version` and rewrites `trackers`. So the live document can be newer than `sources.json` here. Before you publish:

```bash
curl -s https://sources.akidev.live/sources.json -o /tmp/live.json
jq .version /tmp/live.json
# what differs apart from the trackers and the version?
diff <(jq 'del(.trackers,.version)' /tmp/live.json) <(jq 'del(.trackers,.version)' "$SOURCES_DIR/sources.json")
```

- **No differences:** just set `version` above the live one and publish.
- **Differences you did not make:** someone published something that is not in this repo. Do not overwrite it. Bring those changes into this repo first (or build your candidate from the live document with `jq`), then publish.

If this repo's copy holds a change that old apps would refuse (a value they do not know), the old-app check fails. Then either ship the app first and set `OLD_REF` to that release, or build a candidate from the live document with only the safe additions and publish that from a scratch checkout, so the rest of your work is not lost.

## 5. The two feeds, and the old-app check

- An app that knows only schema 1 **refuses** a document that says `"schema": 2`. So the root stays at schema 1 and the same content is also published at schema 2 under `/v2`.
- A value that only schema 2 apps can read (a new kind in the document itself, a new hole name) goes in `sources-v2.json`, next to `sources.json` in this repo. It is published as `/v2` when it exists, and its `version` must equal `sources.json`'s. Until you need that, the two are the same document.
- Old apps ignore unknown **fields** but refuse a whole document with a **value** they do not know. A refused document also stops tracker updates and `min_version`, so the check matters.
- Check a document the way an old release would, without publishing:

  ```bash
  cd <code repo>/desktop
  OLD_REF=desktop-mac-v0.1.27 ./scripts/check-old-apps.sh "$SOURCES_DIR/sources.json"
  ```

  `OLD_REFS="tag1 tag2"` checks exactly those. By default it checks `OLD_REF` (default `desktop-mac-v0.1.17`) and the newest mac tag.

## 6. The daily tracker job

`.github/workflows/refresh-trackers.yml` in the code repo, every day at 04:17 UTC:

- downloads the live document (and the live `/v2` one if there is one);
- runs `scripts/refresh-trackers.sh` (the first 32 `udp` and `http(s)` trackers of `ngosang/trackerslist`, `trackers_all.txt`, best first, WebSocket trackers dropped), and raises `version`;
- signs and publishes both feeds, keeping what the live `/v2` holds that the root does not.

It never touches this repo. A hand edit of `trackers` in the live copy is overwritten by the next run. It needs these secrets in the code repo: `SOURCES_SIGNING_KEY`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`.

## 7. Forcing old apps to update

```json
{ "min_version": "0.1.17", "min_version_message": "This version has a bug that breaks parties. Please update." }
```

- Apps older than `min_version` show an "Update required" screen with the message, an Update button and the download page, and nothing else.
- A malformed `min_version` makes the whole document invalid, so a typo can never lock anyone out.
- The message is up to 300 characters.
- **Publish the release it points to first.** The Update button finds it from the release feed.
- Lift it by publishing a document without the field (or with a lower one) and a higher `version`.

## 8. Rolling back

You cannot go to a lower version: apps ignore it. To undo a bad publish, fix the file (or restore the earlier content) and publish it with a **higher** `version`. Users who already have the bad copy replace it at their next check (about 6 hours).

## 9. Rollout order when code and data change together

If the data uses something new that only new code understands:

1. **Publish the file first.** Old apps ignore new fields, and new code that is not out yet does not use them.
2. Then ship the server and the app.

If you ship code first, it runs without the data it needs. (For example, a server that expects `screens.about` against a live document that lacks it falls back to the built-in copy until the new document is live.)

If the code reads a field that is **required** in the new format (for example `tag` on a tab), a live document without it is refused by the new code, which then keeps its built-in copy. Publish the document first, so that never happens.

## 10. One-time setup (already done)

- An R2 bucket with the custom domain `sources.akidev.live`:

  ```bash
  cf r2 buckets create-by-name akidev-sources
  cf r2 buckets domains custom create akidev-sources --domain sources.akidev.live --zone-id <zone> --min-tls 1.2 --enabled
  ```

- The signing key:

  ```bash
  cargo run -p akidev-core --bin akidev-sources -- keygen .secrets/sources.key
  ```

  It prints the public half, which is `PUBLIC_KEY` in `core/src/sources.rs`. The private file is git-ignored. Keep a copy in a password manager: losing it means shipping a build with a new public key.
