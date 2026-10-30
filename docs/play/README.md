# Publishing Bijou on Google Play

The checklist, in the order it's done, for **Bijou**
(`io.github.yasiralobaidi.bijou`) on phones, tablets, Chromebooks and
Android TV / Google TV. Written 2026-10-27; Play's pages move, so each
rule is linked to where it was read (the list is at the end).

The files beside this one:

| File | What |
|---|---|
| [listing.md](listing.md) | the name, both descriptions, category, contact, tags |
| [data-safety.md](data-safety.md) | the Data safety form's answers and why |
| [demo-playlist.m3u](demo-playlist.m3u) | what Play's reviewers add to try Bijou |
| [../privacy-policy.md](../privacy-policy.md) | the privacy policy |
| `design/brand/play/` | the icon, feature graphic and TV banner (`tools/brand/make_icons.py`) |
| `tools/play_upload_key.sh` | makes the upload key, once |
| `tools/play_bundle.sh` | builds and checks `dist/Bijou-Play.aab` |

Fill in two placeholders first: `[contact email]` (listing.md,
privacy-policy.md) and `[developer name, as on Google Play]`
(privacy-policy.md).

## 1. The developer account

1. https://play.google.com/console/signup with the Google account that
   will own Bijou. Choose a **personal** account (an organization
   account needs a D-U-N-S number). One-time fee: US$25.
2. Verify your identity and your phone as the Console asks (a few days).
3. Know the rule for new personal accounts before you plan a date: a
   **closed test with at least 12 testers, opted in for at least 14 days
   in a row**, before Play lets you apply for production (step 17).
   Collect your 12 testers' Google account emails now.

Android's **developer verification** (enforced since 30 September 2026
in Brazil, Indonesia, Singapore and Thailand, everywhere in 2027) ties
apps installed outside Play to a verified developer too. This account
is where you'd register the sideloaded TV app (`Bijou-TV.apk`) as well;
whether a debug-key-signed app can be registered wasn't checked. Until
then, installs by adb stay possible.

## 2. Create the app

Play Console → **Create app**:

| Field | Answer |
|---|---|
| App name | `Bijou: Your own little cinema` (listing.md) |
| Default language | English (United States) – en-US |
| App or game | **App** |
| Free or paid | **Free** (it can't become paid later) |
| Declarations | Developer Program Policies, US export laws: accept |

## 3. Play App Signing and the upload key

Play signs what it delivers with an **app signing key it keeps** (Play
App Signing, always on for a new app). You sign each upload with your
own **upload key**, which only proves the upload is yours. It can't be
the laptop's debug key that signs the TVs' APK: Play refuses a bundle
signed by "CN=Android Debug".

1. Make the upload key, once, outside the repository:

   ```
   tools/play_upload_key.sh
   ```

   It asks for a password (12 characters or more; save it in your
   password manager first) and writes `~/.android/bijou-play-upload.jks`
   (alias `upload`; the key and the keystore share the password). It
   refuses to overwrite one that is there.
2. **Back it up:** the `.jks` and its password, in two places that
   aren't this laptop. Lost, Play can be asked for a new upload key
   (App integrity → Request upload key reset), which takes days.
3. GitHub → the repository → **Settings → Secrets and variables →
   Actions → New repository secret**, four times:

   | Name | Secret |
   |---|---|
   | `BIJOU_PLAY_KEYSTORE_BASE64` | the line `base64 -w0 ~/.android/bijou-play-upload.jks` prints |
   | `BIJOU_PLAY_KEYSTORE_PASSWORD` | the password |
   | `BIJOU_PLAY_KEY_ALIAS` | `upload` |
   | `BIJOU_PLAY_KEY_PASSWORD` | the same password |

   From then on every `stable-*` release also builds the bundle (the
   **Google Play bundle** job in `.github/workflows/release.yml`) and
   keeps it as the run's artifact **google-play** for 30 days (Actions →
   the run → Artifacts). It isn't a release file and nothing is sent to
   Play. Without the secrets the job only leaves a notice; the release
   is made as before.
4. Or build it on this laptop, from `main` (about 5 minutes; nothing
   else running with Gradle). In fish:

   ```
   set -x BIJOU_PLAY_KEYSTORE ~/.android/bijou-play-upload.jks
   set -x BIJOU_PLAY_KEY_ALIAS upload
   read -s -x -P 'Password: ' BIJOU_PLAY_KEYSTORE_PASSWORD
   set -x BIJOU_PLAY_KEY_PASSWORD $BIJOU_PLAY_KEYSTORE_PASSWORD
   tools/play_bundle.sh
   ```

   (In bash: `export` the same four.) It builds `dist/Bijou-Play.aab`
   for 32- and 64-bit ARM and 64-bit Intel with the commit count as the
   version code, refuses a debug key, checks that every 64-bit library
   is aligned for 16 KB pages, that the app id is
   `io.github.yasiralobaidi.bijou` and that the upload key signed it,
   and prints the version and the key's SHA-256.
5. On the first upload (step 4) Play asks how to sign: keep **"Use a
   Google-generated key"**. Then **Test and release → App integrity →
   App signing** shows two certificates: the upload one must match the
   SHA-256 `tools/play_bundle.sh` printed.

**What this means for the Bijou already installed by hand:** the TVs'
Bijou (and anyone's `Bijou-TV.apk`) is signed with the laptop's debug
key, a Bijou from Play with Google's key. Android updates an app only
with one signed by the same key, so **a device can't move from one to
the other without uninstalling Bijou first**, which deletes its
sign-ins, favorites and history there. Play's Install button says the
app can't be installed while the sideloaded one is there. The two
channels stay apart: the release's `Bijou-TV.apk` keeps the debug key,
and Bijou Beta (`….bijou.beta`) is never uploaded to Play.

## 4. The first upload: internal testing

**Test and release → Testing → Internal testing → Create new release**,
upload `Bijou-Play.aab`, release name "Bijou <build>", notes in plain
words. Add yourself (and anyone helping) as internal testers by email;
the opt-in link installs it from Play within minutes. Nothing here is
public. Every later upload needs a higher version code: the commit count
always grows on `main`.

## 5. The store listing

**Grow users → Store presence → Main store listing**: the texts in
[listing.md](listing.md) (app name 29/30, short description 76/80, full
description 1,637/4,000). **Store settings:** category **Video Players &
Editors**, tags, contact email.

## 6. Graphics and screenshots

| Asset | File, or how |
|---|---|
| App icon 512 × 512 | `design/brand/play/icon-512.png`: the tile edge to edge, Play rounds it |
| Feature graphic 1024 × 500 | `design/brand/play/feature-graphic-1024x500.png` (alt text in listing.md) |
| Phone screenshots | at least 2, better 4 or more at 1080 × 1920 (or 1920 × 1080) |
| 7-inch and 10-inch tablet | 4 or more each, 16:9 or 9:16, 1080–7680 px |
| Chromebook | 4 or more, 16:9 (optional, but they place Bijou in Chromebook lists) |
| Android TV | at least 1 (1920 × 1080), plus the **TV banner** `design/brand/play/tv-banner-1280x720.png` |

Screenshots are the real app, without device frames, with a clean status
bar. **Show only the demo playlist** (step 8): the Blender films, the
test signals, and Bijou's own screens (the welcome, an empty list,
Settings). Never a real channel list, a broadcaster's logo, a sports
match or a film someone else owns; no words like "free channels" over
them. The feature graphic carries the jewel free of its tile (Play asks
for branding that extends the icon rather than repeats it, and for no
near-black field); the icon and the TV banner are the app's own.

## 7. The privacy policy

**Policy and programs → App content → Privacy policy:** the public
address of [privacy-policy.md](../privacy-policy.md):

```
https://github.com/yasir-alobaidi/iptv-player/blob/main/docs/privacy-policy.md
```

(It works once the file is on `main` and pushed. GitHub Pages gives a
plainer page if you turn it on for `docs/`; either is accepted: public,
not a PDF, not editable by others.) Play's User Data policy also wants
**it inside the app**: Settings → About & diagnostics → **Privacy** shows
this same file (bundled with the app, so they can't differ) and the
address above; a TV has no browser to open a link in.

## 8. App access

**App content → App access → All or some functionality is restricted**,
then **Add new instructions**:

- Name: `Demo playlist`
- Username / password: none (leave empty; tick "No other information
  required" if offered)
- Instructions (paste):

  ```
  Bijou is a media player with nothing to watch of its own: users add their own playlists or sign in to services they already use. To try it with openly licensed test media: open Bijou, choose "Add your first source", then "Playlist link", paste https://raw.githubusercontent.com/yasir-alobaidi/iptv-player/main/docs/play/demo-playlist.m3u into Playlist URL, choose "Test connection", "Start sync", then "Finish". Live TV shows test signals; Movies shows the Blender Foundation's open movies (Creative Commons). No account is needed.
  ```

The raw address works once `docs/play/demo-playlist.m3u` is on `main`
and pushed. Try it yourself on the internal-testing install first.

### The demo playlist

Every item answered on 2026-10-27 (`curl -sI`, and a frame decoded with
`ffmpeg`). Under **Live TV** (streams):

| Name | Address host | What, and its licence |
|---|---|---|
| Test Card (live) | demo.unified-streaming.com | Unified Streaming's live test signal (colour bars and a clock), published for testing players; no licence stated |
| Bip-Bop 16:9, Bip-Bop 4:3, Bip-Bop with surround and subtitles | devstreaming-cdn.apple.com | Apple's HLS example streams (test patterns), published for testing players; no licence stated |
| Big Buck Bunny (stream) | test-streams.mux.dev | Mux's test stream of *Big Buck Bunny* © 2008 Blender Foundation, CC BY 3.0 |
| Tears of Steel (stream) | demo.unified-streaming.com | *Tears of Steel* © 2012 Blender Foundation, CC BY 3.0 |

Under **Movies** (files):

| Name | Address host | Licence |
|---|---|---|
| Big Buck Bunny (2008) | media.w3.org | © Blender Foundation, CC BY 3.0 |
| Elephants Dream (2006) | download.blender.org | © Blender Foundation / Netherlands Media Art Institute, CC BY 2.5 |
| Sintel (2010), Sintel (trailer) | download.blender.org, media.w3.org | © Blender Foundation, CC BY 3.0 |
| Tears of Steel (2012) | download.blender.org | © Blender Foundation, CC BY 3.0 |

Left out: the Blender films on `commondatastorage.googleapis.com/gtv-videos-bucket`
(403: no longer public), Bitmovin's Sintel (403), Akamai's live test
stream (its variants answer 404), Mux's `test_001` (a broadcaster's
trailer), `pts_shift` (unknown footage) and `tos_ismc` (ffmpeg can't
decode it), Apple's fMP4 example (no picture decoded), and the second
Unified live stream (the same picture). The playlist has no logos:
Bijou draws its own tiles.

## 9. Ads

**App content → Ads:** "Does your app contain ads?" **No.**
**Advertising ID:** **No** (data-safety.md).

## 10. Content rating

**App content → Content rating → Start questionnaire.** Email: yours.
Category: the one for apps that are neither games nor social, news,
reference or educational apps (labels change; Bijou is a media player).
Answers about Bijou's own content, which is none:

| Question (in substance) | Answer | Why |
|---|---|---|
| Violence, fear, sexual content, nudity, crude language, drugs, alcohol, tobacco, gambling, simulated gambling | **No** | Bijou ships no pictures, video or text of that kind; it shows only what the user adds |
| Users can interact or exchange content with each other (chat, sharing) | **No** | no accounts, no messaging, nothing posted anywhere |
| Shares the user's location | **No** | no location permission or use |
| Digital purchases | **No** | |
| Unrestricted internet access / content from the web, if asked | **Yes** | it opens any address the user gives it; this adds an "unrestricted internet" notice, not a higher age |

Answer truthfully: a rating authority can change the rating after
review, and misstating it can get the app removed.

## 11. Target audience and content

**App content → Target audience and content:** age groups **18 and
over only**. "Could your app unintentionally appeal to children?" **No**.
Store presence: not designed for families.

Why 18+: Bijou has no content of its own, so nothing in it is unsuitable;
but what users watch comes from streams and playlists they add, which
Bijou doesn't filter, and Bijou has no parental lock (hiding a category
isn't a lock). Choosing younger age groups would bring in Play's Families
policy, which a player of unfiltered user-supplied streams can't meet.

## 12. Data safety

**App content → Data safety:** the answers in
[data-safety.md](data-safety.md): no data collected or shared (with the
honest fallback if review disagrees: not encrypted in transit, since
many servers are plain `http`).

## 13. The other declarations

All **No**: Government app, Financial features, Health, News app,
COVID-19 apps, Advertising ID. No foreground-service, photo-and-video,
location or other sensitive permissions are used (the manifest asks for
`INTERNET` only); if the phone work adds one (for example background
audio with a foreground service), it gets its declaration here.

## 14. Android TV

1. **Test and release → Advanced settings → Form factors → Add form
   factor → Android TV**.
2. It needs the **TV banner** (1280 × 720) and **at least one TV
   screenshot** in the listing, and a bundle that installs on TVs (the
   same bundle: one app for every form factor).
3. Opt in and accept the review: Google checks the TV app quality
   criteria before Bijou appears in the Play Store on TVs; the result
   shows on the same page. Fix and opt in again if it's refused.

Where Bijou stands against those criteria (Android's *TV app quality*):

| Criterion | Bijou |
|---|---|
| TV-ML: `ACTION_MAIN` + `LEANBACK_LAUNCHER` | in the manifest |
| TV-LB, TV-BN: a 320 × 180 banner with the name, and an icon | `drawable-xhdpi/banner.png` ("Bijou" beside the jewel), the adaptive icon |
| TV-MT: touchscreen not required | `android.hardware.touchscreen` and `android.software.leanback` `required="false"` |
| TV-DP, TV-DM: everything by D-pad, no Menu key needed | the whole app (docs/07) |
| TV-DB: Back from Home goes to the TV's home | Back on Home ends Bijou (ADR-032) |
| TV-NP: video pauses when the user leaves | playback stops when Bijou leaves the screen (docs/07) |
| TV-PC, TV-PP: OK pauses, play/pause key toggles | OK pauses a film; on a channel OK shows its controls (watch whether the reviewer accepts this for live channels) |
| TV-PS: minimum SDK 31 or lower | 24 |
| TV-G1: an app bundle | `Bijou-Play.aab` |
| TV-OV, TV-TR: nothing cut by the edges, full screen | overscan-safe margins (48 × 27 dp) |

## 15. Large screens and Chromebooks

No opt-in: phones', tablets' and Chromebooks' Play shows Bijou when the
device is compatible. The manifest needs no touchscreen, the bundle has
64-bit Intel (most Chromebooks) besides ARM, and Bijou works with a
keyboard and a mouse. After the first upload, check **Test and release →
Device catalog** for devices Play excludes, and look at the **large
screen** quality notes Play shows there. 32-bit Intel isn't built (old
Chromebooks and emulators only).

## 16. Countries and pricing

**Test and release → Production → Countries / regions:** all, or start
with your own and add more after launch. Free; no in-app products.

## 17. Testing, then production

1. **Internal testing** (step 4): you and a few helpers, every build.
2. **Closed testing → Create track** (or the default "Closed testing –
   Alpha"): upload the same bundle, add a Google Group or an email list
   with **at least 12 testers**, and send them the opt-in link. They must
   accept it and **stay opted in 14 days in a row**; ask them to open
   Bijou a few times and send feedback (Play asks about it). The 14 days
   count only while 12 or more are opted in.
3. **Dashboard → Apply for production** when Play offers it: a few
   questions about the test (who tested, what feedback, what changed).
   Review takes up to about a week.
4. **Production → Create new release**, rolled out to a percentage first
   if you like.

## 18. The policy risk: what keeps Bijou on Play

Google Play doesn't allow apps that **encourage or facilitate
copyright infringement**, including streaming apps whose listing
encourages streaming copyrighted works, and it doesn't allow other
parties' **trademarks, logos or marketing images** in a listing
(Intellectual Property policy). Players of user-supplied playlists have
been removed from Play after rights holders' complaints and court orders
(an Albanian regulator's request; LaLiga in Spain; Perfect Player, on a
complaint later called bogus), and some came back. Bijou's defence is
to be, and to look like, exactly what it is: a player with nothing of
its own.

- **Words:** never "IPTV", "free channels", "subscriptions", "live
  sports", "premium channels", "thousands of channels", "Xtream", a
  service's or a channel's name, in the name, descriptions, screenshots,
  release notes or replies to reviews.
- **Pictures:** only the demo playlist's open media and Bijou's own
  screens; no channel logos, no broadcaster's programmes, no film
  posters someone else owns.
- **The app:** it opens empty with "Add your first source", comes with
  no playlists, links or suggestions of where to get any, and its
  examples are `example.com` (docs/05 "Brand"). Keep it so: no "find
  playlists" link, no bundled lists.
- **The demo:** only the playlist above.
- **Support:** don't answer "where do I get channels?" anywhere public.

If a complaint removes Bijou, Play Console sends the notice and an
appeal form: answer with the above (the app supplies no content, the
listing shows only open media) and the policy pages below.

## Sources

Read on 2026-10-27:

- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465) (12 testers, 14 days, accounts created after 13 November 2023)
- [Intellectual Property (Play Console Help)](https://support.google.com/googleplay/android-developer/answer/9888072) (encouraging infringement, trademarks and marketing images in listings)
- [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311) (privacy policy in the Console and in the app; what it must contain)
- [Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469) (collection, sharing, exemptions)
- [Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151) (icon, feature graphic, screenshots, TV banner)
- [Distribute to Android TV](https://developer.android.com/training/tv/publishing/distribute) (Advanced settings → Form factors)
- [TV app quality](https://developer.android.com/docs/quality-guidelines/tv-app-quality) (the TV- criteria above)
- [Content ratings](https://support.google.com/googleplay/android-developer/answer/188189) (the questionnaire)
- [VLC's Data safety page](https://play.google.com/store/apps/datasafety?id=org.videolan.vlc) (a network-capable player's "No data collected")
- Removals: [AMA (Albania) on One IPTV Player](https://ama.gov.al/at-amas-request-the-one-iptv-player-application-was-removed-from-google-play-for-the-illegal-streaming-of-albanian-television-channels/?lang=en), [Genbeta on LaLiga and IPTV Smarters Pro](https://www.genbeta.com/actualidad/laliga-obliga-a-iptv-smarters-pro-a-desaparecer-google-play-store-prometen-que-atacaran-a-apps-iptv), [TorrentFreak on Perfect Player](https://torrentfreak.com/google-play-removes-perfect-player-after-bogus-copyright-complaint-191019/)
- [Android developer verification timeline (Android Authority)](https://www.androidauthority.com/android-sideloading-changes-timeline-3679204/)
