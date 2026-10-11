# Fake Cast receiver

A Cast device on 127.0.0.1 for tests and manual runs: Cast v2 over TLS
with the Default Media Receiver, as the app's own client speaks it
(docs/04). It is Phase 7's decision 8 (docs/plans/phase-7-casting.md);
docs/06 describes it beside the fake provider.

It never advertises itself on the network. Tests and the app reach it by
its address (Add device by address: `127.0.0.1:<port>`).

## Run it

```bash
dart run tools/fake_receiver/bin/fake_receiver.dart --port 8010
```

| Flag | Default | |
|---|---|---|
| `--port` | `8010` | |
| `--host` | `127.0.0.1` | |
| `--name` | `Fake TV` | what MULTIZONE_STATUS names it |
| `--launch-delay-ms` | `0` | Living Room TV takes 3000–6000 |
| `--load-delay-ms` | `300` | LOAD → BUFFERING → PLAYING (without `--ffprobe`) |
| `--ffprobe` | none | plays for real: fetches what LOAD names and checks it with this ffprobe |
| `--device` | `tv4k` | with `--ffprobe`: `tv4k`, `chromecast-hd` (1080p, H.264 only), `tv-hd-link` (a 4K TV on a 1080p HDMI link) |
| `--verbose` | off | prints every message received |

## In a test

```dart
final fake = await FakeReceiver.start(launchDelay: Duration(seconds: 3));
// … CastAddress(fake.host, fake.port) …
fake.dropConnections();             // a Wi-Fi blip
await fake.close();
```

## What it does like the TV
Each of these was seen on Living Room TV in Phase 0 (spike/cast_spike/results):
- Takes a destination's messages only after a CONNECT to it.
- Sends LAUNCH_STATUS (`status` is a string) before the answer to LAUNCH,
  which comes once the receiver runs.
- Answers a request and also sends the same status to every sender with
  `requestId: 0`.
- Answers LOAD with a MEDIA_STATUS at once (IDLE, `extendedStatus`
  LOADING). A LOAD it refuses gets a LOAD_FAILED as a second answer to the
  same request, then IDLE/ERROR. Status updates leave `media` out.
- After STOP or an error the media session is gone: a command on it
  answers INVALID_REQUEST / INVALID_MEDIA_SESSION_ID.
- A fixed volume (`controlType: fixed`): SET_VOLUME changes nothing.
- MULTIZONE_STATUS names the device and gives its id as a UUID.

## Faults
| | |
|---|---|
| `silent` | answers nothing, sends no PINGs |
| `heartbeat = false` | stops PONGs and its own PINGs only |
| `dropConnections()` | closes every sender's connection; the receiver keeps running |
| `refuseConnections` | closes new connections at once |
| `refuseLaunch` | LAUNCH_ERROR (`NOT_ALLOWED`) |
| `refuseLoads(test)` | LOAD_FAILED for the media `test` matches |
| `startOtherApp()` | YouTube takes the device |
| `remotePause()` `remotePlay()` `remoteBack()` | the TV's remote |
| `sendRaw(bytes)` `sendJson(namespace, payload)` | anything, to every sender |

## Playing for real (Phase 7 step 5)
With `playback: FakePlayback(ffprobe: …)` (or `--ffprobe`), a LOAD is
fetched the way the TV fetches it, and the media session follows what
arrived:
- **HLS** (`application/x-mpegurl`): the playlist polled every half
  segment, from the live edge (the last three segments), each new segment
  read and checked with ffprobe — codec, height, channels and **frames**,
  since a stream named in a header with nothing behind it plays nothing.
  Every request carries `Origin: https://www.gstatic.com`; an answer
  without `Access-Control-Allow-Origin` is dropped, as the TV's browser
  drops it. PLAYING once the first segment checks out; BUFFERING after
  three segment lengths with nothing new, PLAYING again when something
  comes; IDLE/ERROR when the playlist goes unreadable for `giveUp`, or its
  numbering goes back (a restart that didn't continue it); `#EXT-X-
  DISCONTINUITY` is recorded on the segment after it; `#EXT-X-ENDLIST`
  plays out to IDLE/FINISHED.
- **A continuous stream** (`video/mp4` with no length: the relay's): read
  from the start with `Range: bytes=0-`; its first 256 KB checked;
  IDLE/FINISHED after its end and `endDelay` (Living Room TV plays out
  about 4 s).
- **A file with a length** (a direct play; Phase 8 step 7): an answer
  with `Content-Range` or `Content-Length` + `Accept-Ranges` is a file,
  not the relay's stream. Its first 4 MB are checked and its length read
  from them (an index at the front); it is then read `bufferAhead` past
  where it plays, and not at all while paused. A **SEEK**, or a LOAD that
  starts past 0:00, is a new request with `Range: bytes=<n>-` at the byte
  that time is at (what the TV did in Phase 0); an answer other than 206
  fails it. FINISHED once it has played to its end. A file whose index
  isn't at the front is read to its end and finished, as before.
- **Text tracks** (docs/04 "Subtitles"; Phase 8 step 7): LOAD's
  `media.tracks` of type `TEXT` are each fetched beside the media, with
  the receiver's `Origin`, and read as WebVTT: `textTracks` says how many
  cues each holds, when the first shows and what it says, or why the TV
  would show nothing of it (`HTTP 404`, `no CORS header`, `not WebVTT`,
  a type other than `text/vtt`). A track that can't be read never fails
  the LOAD. `activeTrackIds` is LOAD's, then **EDIT_TRACKS_INFO**'s (an
  id the LOAD didn't name is `INVALID_REQUEST` / `INVALID_PARAMS`), and
  is in every MEDIA_STATUS of a media that has tracks.
- **A buffer, as a TV's** (Phase 7 step 7): a fragmented MP4 (the relay's
  continuous stream) is read until it holds `bufferAhead` (30 s) more
  than has played, then not again until it holds less than
  `bufferRefill` (10 s); nothing while paused. Each fragment's start
  (`moof/traf/tfdt`) says how far the bytes go. A relayed file, which
  FFmpeg copies far faster than it plays, then waits on the TV for tens
  of seconds at a time, as on a real TV; at the stream's end, what it
  holds is played out first. `bufferAhead: null` reads as fast as it
  comes.
- **The device profiles** (`FakeDevice.tv4k`, `chromecastHd`,
  `tvOnHdLink`): a picture the device refuses (HEVC on an H.264-only
  device, taller than its picture or its HDMI link) gets a bare
  LOAD_FAILED `refuseDelay` after its first segment, then IDLE/ERROR, as
  docs/04 describes the TV on a 1080p link.
- `fetches` and `checks` (and `onChecked`) say what was fetched and what
  ffprobe found, so a test can check video and sound really arrived.

Without it, the fake plays anything it's told to after `loadDelay`, as
before.

## Its wire format
`lib/src/cast_wire.dart` reads and writes the `CastMessage` protobuf by
hand, independently of the app's generated code, so an encoding mistake on
either side shows in the tests. `test/cast_wire_test.dart` checks it
against bytes from `protoc --encode`.

The TLS certificate in `lib/src/test_certificate.dart` is test-only: a
self-signed key, public on purpose, that guards nothing.
