# Fake IPTV provider

A local Xtream Codes panel with generated data and real video, for tests and
for running the app without a real provider. Specified in
[docs/06-quality.md](../../docs/06-quality.md) ("Fake provider"); the API it
imitates is in [docs/02-providers-and-data.md](../../docs/02-providers-and-data.md).

This is Phase 1 step 6, the skeleton: the Xtream API, live streams, and the
fault set as a stub. What is still missing is listed at the bottom.

## Run it

```bash
dart run tools/fake_provider/bin/server.dart --port 8899
```

Then add a source in the app, or check it by hand:

```bash
curl -s 'http://127.0.0.1:8899/player_api.php?username=test&password=test' | head -c 400
curl -s 'http://127.0.0.1:8899/player_api.php?username=test&password=test&action=get_live_streams' | head -c 400
mpv 'http://127.0.0.1:8899/live/test/test/1.ts'
```

No flags needed: the samples directory, the bundled ffmpeg and a run
directory under the system temp directory are all resolved from the repo.
`--help` lists every flag. The ones that matter:

| Flag | Default | |
|---|---|---|
| `--port` | `8899` | |
| `--host` | `127.0.0.1` | `0.0.0.0` to reach it from a TV on the LAN |
| `--profile` | `default` | see below |
| `--samples` | `tools/media_samples/out` | built by `tools/media_samples/generate.sh` |
| `--ffmpeg` | `third_party/ffmpeg/<platform>/ffmpeg` | falls back to `ffmpeg` on `PATH` |
| `--run-dir` | `$TMPDIR/iptv_fake_provider` | PID files and the MKV loop cache |
| `--live` `--movies` `--series` `--max-connections` | from the profile | override one number without a new profile |
| `--username` `--password` | `test` / `test` | |
| `--verbose` | off | logs requests (credentials redacted) and ffmpeg's stderr |

## Profiles

| Profile | Channels | Movies | Series | For |
|---|---|---|---|---|
| `default` | 240 | 120 | 24 | day-to-day runs and integration tests |
| `large` | 50,000 | 30,000 | 3,000 | the docs/06 sync and scroll budgets |
| `quirky` | 320 | 200 | 40 | every quirk docs/02 says the parser must tolerate |

Data is generated from the profile's seed and is **deterministic**: the same
profile always produces the same channels, so a test can assert on channel
4211. It is also generated **lazily**, per id, which is what makes the
`large` profile start instantly.

`quirky` turns on numbers as strings, `""` for null, `info: []`, episodes as
a map keyed by season, invalid UTF-8 in names, dangling and missing
`category_id`s, junk icon URLs, HTML entities in names, and a messy
`get.php` (CRLF, `#EXTVLCOPT`, `#KODIPROP`).

## Endpoints

- `GET /player_api.php?username=&password=` — `user_info` + `server_info`.
  `server_info.url` and `port` follow the request's `Host`, so a client that
  rebuilds stream URLs from them comes back to this server.
- `&action=` `get_live_categories` · `get_live_streams` · `get_vod_categories` ·
  `get_vod_streams` · `get_series_categories` · `get_series` ·
  `get_vod_info` · `get_series_info` · `get_short_epg`, each with the
  optional `category_id` / id / `limit` parameters docs/02 lists. Any other
  action answers **501** and names the ones it knows, so a phase that needs
  a new action fails loudly instead of parsing silence.
- `GET /get.php?username=&password=[&type=m3u_plus|m3u][&output=ts|m3u8]` —
  the whole catalogue as an Xtream-style M3U export: live, then movies, then
  every episode (named `Series S01 E02`), streamed an entry at a time. Wrong
  credentials answer **401**. The `messyM3u` quirk (on in `quirky`) adds
  CRLF line ends, `#EXTVLCOPT` and `#KODIPROP` lines.
- `GET /xmltv.php?username=&password=[&days=][&channels=][&gzip=1]` — the
  guide for every channel with an `epg_channel_id`, from the same schedule
  `get_short_epg` answers from; the `messyXmltv` quirk (and per-request
  flags) add docs/02's XMLTV quirks.
- `GET /live/{username}/{password}/{stream_id}.ts` — MPEG-TS, looped forever;
  `.m3u8` is live HLS (2 s segments from `/hls/{id}/`).
- `GET|HEAD /movie/{username}/{password}/{stream_id}.{ext}` and
  `/series/{username}/{password}/{episode_id}.{ext}` — the item's VOD sample
  as a panel serves a file: `Range` (206, open ends, suffixes, 416),
  `ETag`, `Last-Modified`, `If-Range`. The extension must be the item's
  `container_extension`. An open body holds a connection slot, except that
  a new request for the same file takes over the open one and closes it —
  what a player's seek needs on a one-connection panel.
- `GET /art/{live|movie|series|episode}/{id}.{png|jpg}` and
  `/art/backdrop/{movie|series}/{id}.jpg` — channel logos (256 px), posters
  (600 × 900), episode stills (500 × 281) and backdrops (1280 × 720): a few
  generated PNGs per kind, drawn once, served under every item's name with
  an `ETag`. Every artwork URL in the API, `get.php` and `xmltv.php` points
  here, at the host the client used; `junkIcons` still breaks some.
- `GET|POST|DELETE /admin/faults` — read, replace, or clear the fault set.
- `GET /` — a plain-text summary of the running profile.

Wrong credentials answer the way a real panel does: **200** with
`{"user_info":{"auth":0}}` on the API, and **401** on a stream.

## Streams loop an MKV, never the `.ts`

The samples in `tools/media_samples/out` are MPEG-TS, but looping a TS file
with `-stream_loop -1` breaks the video timestamps at every wrap — about a
hundred decode errors and a visible freeze on a TV (docs/06, ADR-004
Finding 8). So each sample is remuxed to Matroska once into
`<run-dir>/loop_cache/`, written as `.part` and renamed only after ffmpeg
exits cleanly (hard rule 11), and the loop runs from that. Even from MKV a
wrap leaves one gap under 0.1 s and a few decode errors, so tests don't
assert on frames around a wrap.

Every ffmpeg process has a PID file in `<run-dir>/pids/`, is killed when the
client disconnects and on shutdown, and a leftover process from a previous
run is cleaned up at startup (hard rule 8). `max_connections` is enforced;
past the limit a stream answers **403** with `MAX_CONNECTIONS_REACHED`, and
`user_info.active_cons` reports the current count.

## Used by the app's tests

The app depends on this package as a path dev-dependency, and its tests
start the server in-process on port 0 (see docs/06, which also has the two
traps: flutter_test's fake `HttpClient`, and jank measurements needing the
server in its own process).

## Tests

```bash
cd tools/fake_provider && dart test
```

The tests that run ffmpeg skip themselves with a reason when the binary or
the samples are missing, so the suite passes on a bare checkout. `dart
analyze` and `dart format` cover this package with the app's lints
(`dart format --set-exit-if-changed lib test integration_test tools` from
the repo root includes it).

## Faults

Set with `POST /admin/faults` (the whole set) or per request in the query
(`/live/test/test/7.ts?drop_after_s=5`):

- Live: `drop_after_s`, `stall_after_s`, `cut_after_s`, `slow_start_ms`,
  `http_status`, `max_connections`, `redirect_with_expiring_token`,
  `codec_switch_after_s` (`lib/streams.dart`).
- VOD files: `http_status`, `slow_start_ms`, `max_connections`,
  `ignore_range` (the whole file for any range), `drop_after_bytes` (the
  connection closes once a body passes that byte of the file, so a request
  starting past it gets through) and `throttle_kbps` (kilobits per second)
  (`lib/vod.dart`).
- Downloads (Phase 8, `lib/vod.dart`): `change_etag` (every answer has a
  new ETag and Last-Modified, so a resume's `If-Range` never matches and
  gets the whole file), `wrong_content_length` (Content-Length 4 KiB past
  the body, then the connection closes), `size_mb` (the file padded to that
  many MiB with `fakePaddingByte`s made as they are sent, for the 4 GB
  measurement) and `vod_as_hls` (the movie or episode answers an HLS VOD
  playlist of 4 s TS segments under `/vodhls/<sample>/`, cut once with
  ffmpeg into the run folder; each segment holds a connection slot while it
  is sent). `If-Range` is checked before the range, as HTTP has it.
