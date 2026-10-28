# Bijou's Data safety answers

Play Console → **Policy and programs → App content → Data safety**. The
answers, with the reasons, as of build 0.1.0 (2026-10-27). Answer again
whenever the app starts sending anything new anywhere.

## What Google counts

From [Data safety: Play Console Help](https://support.google.com/googleplay/android-developer/answer/10787469):
"collect" means "transmitting data from your app off a user's device";
"sharing" means "transferring user data collected from your app to a third
party". Data handled only on the device isn't declared. An app that
collects nothing still fills in the form and gives a privacy policy.

## What Bijou keeps, on the device only

| What | Where | Why |
|---|---|---|
| The password (and username) of a **Server login** source | Android's encrypted storage (flutter_secure_storage: encrypted with a key held in the Android Keystore) | to sign in to the user's service |
| Sources (names, addresses), the channel, movie and series lists, the program guide, favorites, watch history and positions, hidden categories, settings | the app's own database (SQLite) in its private folder | the app's library and state |
| Artwork | the app's cache folder (64 MB of images and 150 MB of pictures at most on a TV) | to show posters and logos quickly |
| Bijou's own log, and on a TV the report of past runs | the app's private folder, passwords and credential-bearing addresses removed (`redact()`, CLAUDE.md hard rule 3) | to explain a problem when the user asks |

Nothing of this is sent to the developer, and none of it leaves the
device except as the next section says.

## What leaves the device

Only requests to the addresses the user adds, made because the user
added them:

- the user's service (the **Server login**: its address, username and
  password, as that service's sign-in requires);
- the playlist and guide links the user enters;
- the stream, poster and logo addresses those playlists and services
  name.

On a TV, **Send to phone** (Settings → About & diagnostics) serves the
redacted report on the home network for the user's own phone, while the
dialog is open and only at a random address the TV shows: a transfer the
user starts, to the user.

**Nothing goes to the developer:** there is no server of Bijou's, no
analytics, no advertising, no crash reporting service. What was checked
(2026-10-27, on `dev` at `cf2921a`):

- `pubspec.yaml`'s dependencies and the 195 packages in `pubspec.lock`:
  no Firebase, Crashlytics, Sentry, Bugsnag, App Center, Amplitude,
  Mixpanel, PostHog, Datadog, Instabug, AdMob / google_mobile_ads or any
  other analytics, ads or crash SDK;
- `grep -rniE "firebase|crashlytics|sentry|analytics|bugsnag|appcenter|amplitude|mixpanel|admob|google_mobile_ads|telemetry|datadog|newrelic|posthog|instabug"`
  over `lib/`, `pubspec.yaml` and `android/`: nothing;
- every `http://` and `https://` address written in `lib/`: only
  `example.com` hints, licence links shown in About, and Google's Cast
  receiver (`www.gstatic.com`), which is the desktop's casting and isn't
  in the Android app;
- the manifest asks for the `INTERNET` permission only (no location,
  contacts, camera, microphone, storage or advertising ID).

Recheck this list before each Play release that adds a package or a
permission (the phone work may add `POST_NOTIFICATIONS` for reminders;
that changes nothing here, as notifications are local).

## The answers

**Does your app collect or share any of the required user data types?**
**No.**

Bijou's developer receives nothing, and Bijou sends the user's data
only where the user pointed it: the server the user signs in to is the
user's own choice, as a web address typed into a browser is. Google's
help gives the nearest case in so many words: an app need not declare
collection when "the user chooses to upload their data directly to their
own external drive or cloud storage account" and the app never collects
or accesses it. VLC, a player that also opens network streams and signs
in to servers the user adds, answers the same: "No data collected", "No
data shared with third parties"
([VLC's Data safety page](https://play.google.com/store/apps/datasafety?id=org.videolan.vlc)).

With "No", Play skips the security questions and the listing reads "No
data collected" and "No data shared with third parties".

### If Play's review disagrees

Google's text doesn't speak of servers the user configures, so a
reviewer could count the sign-in as collection. Then answer, honestly:

| Question | Answer | Why |
|---|---|---|
| Data types | **Personal info → User IDs** (the service's username), collected, not shared | it goes to the user's service at sign-in |
| Is it processed ephemerally? | No | it is kept (encrypted) for the next sign-in |
| Required or optional? | Optional | a playlist link needs no sign-in |
| Purpose | App functionality | |
| **Is all of the user data collected by your app encrypted in transit?** | **No** | Bijou uses whatever the user's server speaks, and many services and playlists are plain `http` (the manifest allows cleartext for that reason). Never answer Yes. |
| **Do you provide a way for users to request that their data is deleted?** | Yes | Remove the source (Settings → Sources), clear the data (Settings → Data), or uninstall: all of it is on the device. The developer holds nothing to delete. |

## Data deletion, for the privacy policy and any question

- Remove a source: Settings → Sources → the source → Remove (its
  password goes with it).
- Clear pictures, the guide, watch history: Settings → Data.
- Everything: uninstall Bijou, or Android's Settings → Apps → Bijou →
  Storage → Clear storage.

Bijou creates no account, so Play's account-deletion requirement (a
deletion link for apps where users create an account) doesn't apply.

## Nearby declarations in App content

- **Advertising ID:** "Does your app use advertising ID?" **No.** (No
  `com.google.android.gms.permission.AD_ID` in the manifest. After a
  build, `aapt2 dump permissions` on the bundle's APKs confirms no
  library merged it in.)
- **Ads:** "Does your app contain ads?" **No.**
