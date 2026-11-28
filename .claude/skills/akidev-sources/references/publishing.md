# Publishing

Publishing changes what every user's app and the server do within hours. **Do it only when the user asks.** Editing, validating and testing are free.

## Contents

1. How a change travels
2. Before you publish: the checklist
3. Publish
4. The live copy can be ahead of this repo
5. The two feeds, and the old-app check
6. The tracker job (removed)
7. Forcing old apps to update
8. Rolling back
9. Rollout order when code and data change together
10. One-time setup (already done)

---

## 1. How a change travels

1. You edit `sources.json` in this repo and raise `version`.
2. You check the file, check that old apps would accept it, sign it with the private key and upload it to a Cloudflare R2 bucket, shown at `sources.akidev.live`. The steps are in section 3. (The `publish-sources.sh` and `check-old-apps.sh` scripts were removed from the code repo in commit `5779987`; they are still in its history: `git show 5779987^:content/sources/publish-sources.sh`.)
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
- [ ] `cargo test -p akidev-core -p akidev-server` passes with your copy in `crates/core/sources.json` (the website's `apps/web/test/screens.fixture.json` is a copy of the screens: update it too when `screens` changes).
- [ ] You tried the real request for anything new, and kept a fixture test for it.
- [ ] `screens.about` names every catalogue and subtitle source that is in the file.
- [ ] If the file uses a new field or value that only newer code understands, the code that reads it is already released (or you are about to release it: see section 9).
- [ ] You know which releases are the oldest you still support (a desktop tag such as `desktop-mac-v0.1.27`, and `tv-android-v1.0.0`).
- [ ] The `cf` CLI is logged in and the signing key exists (`.secrets/sources.key` in the code repo, or `KEY=`).
- [ ] If the change needs new code (a new key such as a row `style`), the server with that code is deployed first (section 9).
- [ ] You have said, in plain words, what will change for users.

## 3. Publish

Run from `<code repo>`. Use a scratch folder, `$W`, and the path of this repo, `$S` (the `sources.json` file).

```bash
T="cargo run -q -p akidev-core --bin akidev-sources --"
W=$(mktemp -d)

# 1. Keep a copy of what is live (a published version cannot be taken back).
mkdir -p $W/live/v2
for f in sources.json sources.sig v2/sources.json v2/sources.sig; do curl -fsSL "https://sources.akidev.live/$f" -o "$W/live/$f"; done
jq -c '{schema,version}' $W/live/sources.json     # your version must be higher

# 2. Make the schema 2 copy, sign both, and check both signatures.
jq '.schema = 2' $S > $W/sources-v2.json
$T sign .secrets/sources.key $S $W/sources.sig && $T check $S $W/sources.sig
$T sign .secrets/sources.key $W/sources-v2.json $W/sources-v2.sig && $T check $W/sources-v2.json $W/sources-v2.sig

# 3. Upload /v2 first, then the root, so a build that knows the newer feed never sees the older one ahead of it.
put() { cf r2 objects put "$1" --bucket-name akidev-sources --file "$2" --content-type "$3" > /dev/null && echo "put $1"; }
put v2/sources.json $W/sources-v2.json application/json
put v2/sources.sig  $W/sources-v2.sig  text/plain
put sources.json    $S                 application/json
put sources.sig     $W/sources.sig     text/plain
```

Check afterwards (download again and verify the signature, not only the version):

```bash
mkdir -p $W/verify/v2
for f in sources.json sources.sig v2/sources.json v2/sources.sig; do curl -fsSL "https://sources.akidev.live/$f?t=$RANDOM" -o "$W/verify/$f"; done
$T check $W/verify/sources.json $W/verify/sources.sig
$T check $W/verify/v2/sources.json $W/verify/v2/sources.sig
cmp $W/verify/sources.json $S && echo "live equals the repo file"
```

Both feeds should show the new version, with schema 1 and 2. The `cf` CLI must be logged in to the Cloudflare account, and `.secrets/sources.key` must exist in the code repo.

## 4. The live copy can be ahead of this repo

It used to be, because a daily job rewrote `trackers` in the live copy only. That job was removed (section 6), so the live copy is what was last published from this repo. Still compare before you publish, in case someone published from another checkout:

```bash
diff <(jq -S 'del(.version)' $W/live/sources.json) <(jq -S 'del(.version)' $S)
```

Differences you did not make mean someone published something that is not in this repo. Do not overwrite it. Bring it into this repo first.

If this repo's copy holds a change that old apps would refuse (a value they do not know), the old-app check (section 5) fails. Then ship the app first, or leave that part out of this publish.

## 5. The two feeds, and the old-app check

- An app that knows only schema 1 **refuses** a document that says `"schema": 2`. So the root stays at schema 1 and the same content is also published at schema 2 under `/v2`.
- A value that only schema 2 apps can read (a new kind in the document itself, a new hole name) goes in `sources-v2.json`, next to `sources.json` in this repo. It is published as `/v2` when it exists, and its `version` must equal `sources.json`'s. Until you need that, the two are the same document.
- Old apps ignore unknown **fields** but refuse a whole document with a **value** they do not know. A refused document also stops tracker updates and `min_version`, so the check matters.
- Check a document the way an old release would, without publishing. Build the checker of an old release from its git tag and run it on your file:

  ```bash
  S=<path to akidev-sources>/sources.json
  for ref in desktop-mac-v0.1.27 desktop-mac-v0.1.36 desktop-mac-v0.1.37 tv-android-v1.0.0; do
    git worktree add -q --detach /tmp/old-$ref $ref
    # tags before the move of the Cargo workspace (up to v0.1.36) keep it in desktop/; later tags have it at the root
    dir=/tmp/old-$ref; [ -d $dir/desktop/core ] && dir=$dir/desktop
    echo "Checking with $ref"; (cd $dir && cargo run -q -p akidev-core --bin akidev-sources -- check $S)
    git worktree remove --force /tmp/old-$ref
  done
  ```

  Every one must print `version N: ... providers`. A refusal names the value.

## 6. The tracker job (removed)

A daily workflow used to refresh `trackers` in the live copy. It was removed from the code repo in commit `5779987`, so nothing raises `version` or rewrites `trackers` by itself now. `trackers` in `sources.json` is edited by hand when it needs it, and published like any change.

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

**The exception:** when the server has to *do* something with the new data, ship the server first. A row `style` of `ranked` is an example. The server cuts a ranked row to ten and sends `style`. If the document is published first, the website shows "Top 10" over 24 plain tiles until the deploy ends. So: deploy the server, then publish the document.

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

  It prints the public half, which is `PUBLIC_KEY` in `crates/core/src/sources.rs`. The private file is git-ignored. Keep a copy in a password manager: losing it means shipping a build with a new public key.
