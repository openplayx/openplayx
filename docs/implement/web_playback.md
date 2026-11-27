# LAN Web playback (Direct Play)

The desktop App exposes **Settings → Web playback** on macOS, Windows and Linux.
The service is off after each launch. Choose a private IPv4 interface, enable the
service (port 8090), explicitly select library folders to share, and open the shown
address in another device's browser. Enter the desktop's five-minute pairing code.
Keep the App running and use a trusted LAN: the transport is HTTP.

## Implemented behavior

- Self-contained responsive browser UI, English / Chinese labels, search and
  paginated files. The list contains real scanned files, including episodes and
  separate versions; it does not expose source addresses, passwords or file paths.
- Native browser media playback with GET / HEAD and single byte ranges (206 /
  Content-Range / 416), including suffix and open-ended ranges. Seeking uses the
  original source's random access. Browser codec support determines playability.
- Local files and existing host-owned loopback HTTP source gateways; upstream
  redirects are refused. Remote sources which resolve to an external URL are not
  exposed directly. Their upstream native playback profile is not a Web profile.
- Resume and progress through the existing library session guard. The most recently
  started session for a resource owns its progress, matching native playback.
- One playback session per paired device, up to eight playback sessions and sixteen
  paired devices. A desktop action, changed share scope or source visibility can end
  a session. Browser progress refreshes its 90-second idle lease every ten seconds,
  including while paused; abandoned sessions are reclaimed by periodic maintenance.
- Sharing choices persist in `configuration.sqlite3`, namespace `web_playback`.
  New folders remain private. Service enablement and pairing credentials are not
  persisted. Stopping the service invalidates every device cookie and releases
  playback handles; the App drains HTTP work before closing its library/sources.

## Boundaries

The listener binds one selected private interface, not `0.0.0.0`. Only loopback or
private IPv4 peers and the exact listener Host are accepted. Origins must match.
Mutations require JSON plus a custom request header. Cookies are HttpOnly,
SameSite=Strict and expire after twelve hours. Pair attempts are rate limited;
request body sizes, concurrent requests and device counts are bounded. Static assets
use a restrictive same-origin CSP and do not depend on an external CDN.

Each catalog/stream/progress request checks current sharing and enabled file source
and account visibility. Catalog SQL binds values and requires available scan evidence
and the locator of the observing scope's connection. Arbitrary file paths and URLs
are not accepted by any browser endpoint. Progress updates are reported to the App's
library change stream. Media errors are short codes, not upstream exception text.

## Current limits

This is the Direct Play release. It does not implement HLS, Remux, audio/video
transcoding, subtitle conversion, HDR mapping, TV-specific capability profiles,
mobile hosting, HTTPS, Relay access or automatic port mapping. Existing FFmpeg file
jobs are not used for streaming. Browser incompatibility is shown explicitly.
The App must remain awake/running. Source performance and random access still depend
on its existing gateway. Only scanned, enabled library folders can be shared.

## Validation

```sh
flutter test test/capabilities/web_playback \
  test/features/settings/web_playback_settings_page_test.dart
```

For real browser playback, supply a locally installed Playwright or Playwright Core
ES module, and Chrome (default macOS path, override with `CHROME_PATH`):

```sh
OPX_PLAYWRIGHT_MODULE=/absolute/path/to/playwright-core/index.mjs \
  flutter test test/capabilities/web_playback/web_playback_browser_test.dart
```

The browser test starts the real Dart service with a fixture catalog. It pairs,
plays the fixture MP4, seeks, verifies progress/resume, checks the 390px layout,
and logs out. Desktop/mobile screenshots are generated under `build/web-playback/`.
The optional browser test is skipped unless its module path is provided.
