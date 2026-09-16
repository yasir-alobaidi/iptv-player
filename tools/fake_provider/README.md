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
`category_id`s, junk icon URLs, and HTML entities in names.

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
- `GET /live/{username}/{password}/{stream_id}.ts` — MPEG-TS, looped forever.
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

## Tests

```bash
cd tools/fake_provider && dart test
```

The tests that run ffmpeg skip themselves with a reason when the binary or
the samples are missing, so the suite passes on a bare checkout. `dart
analyze` and `dart format` cover this package with the app's lints
(`dart format --set-exit-if-changed lib test integration_test tools` from
the repo root includes it).

## Not here yet

By design — each arrives with the phase that tests it (docs/06):

- `get.php` (M3U output) and `xmltv.php`, including gzip and a 300 MB EPG —
  Phase 2, which owns the M3U and XMLTV parsers.
- VOD files over HTTP with Range, ETag and `Last-Modified`, `vod_as_hls`,
  and `size_mb` padding — the download and library phases. `/movie/…` and
  `/series/…` answer 501 until then.
- `m3u8` live output.
- **Fault injection.** The fault set is stored and reported, and nothing
  reads it yet apart from `max_connections`. Each fault gets injected by the
  phase whose tests need it.
