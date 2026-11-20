# Cloud drive sources / 云盘来源

Implementation: 2026-11-17. Account acceptance is pending. These are built-in
source adapters, accessed through the existing source/library AI tools.

## User setup / 用户配置

- **坚果云 / Jianguoyun**: Sources → Add → WebDAV → preset 坚果云.
  The default endpoint is `https://dav.jianguoyun.com/dav/`. Enter your account
  and a **third-party application password**, not your main password. Change
  the directory under Advanced when needed.
- **123 云盘 / 123 Cloud Drive**: Sources → Add → WebDAV → preset 123 云盘.
  Confirm that your account has WebDAV access, then copy the endpoint and
  credentials from the official console. No endpoint or unlimited-speed claim
  is supplied by the app; account plans and transfer limits require validation.
- **OneDrive**: Sources → Add → OneDrive → Sign in with browser. This build
  supports personal Microsoft accounts only. The publisher must configure its
  public OAuth app first; users do not supply developer keys.
- **百度网盘 / Baidu Netdisk**: 浏览器登录、选择全部文件或目录、扫描和播放；
  发布方需要自己的获批应用及服务端授权桥接。参见[配置和验收](baidu_netdisk_source.md)。
- **Dropbox**: Sources → Add → Dropbox → Sign in with browser. The publisher
  must configure a Scoped App with Full Dropbox content access first.

For OneDrive/Dropbox, open a folder to select it as the root, then save. The
current folder is selected; Back returns to the preceding selection. Opening
Selected root folder loads its children when editing a saved connection.
Signing in again starts selection from the account root. Add a file source
under the saved connection to scan it into the library. Multiple instances have
separate credentials and resource namespaces.

坚果云、123 云盘位于 WebDAV 的预设中。OneDrive、Dropbox 使用浏览器登录，
打开文件夹即可选为根目录，再保存连接。编辑连接时点击“已选根目录”加载子目录；
重新登录可从账号根目录重新选择。保存后在连接下添加文件来源，再扫描入库。
每个来源实例单独保存凭据，可添加多个账号。

Editing an OAuth connection, connection tests and playback share one account
session. Token rotation is persisted immediately even if a form is cancelled.
Access is checked against the selected root again for restored library refs;
moving a file outside the root makes that reference inaccessible.

Use **Disconnect account** in the cloud form (or delete the source) to stop
local requests and erase the local credential. Also remove OpenPlayX in your
Microsoft account permissions / Dropbox Settings → Apps to revoke the platform
grant. The app does not revoke an external grant automatically. Disconnecting
interrupts current cloud playback. Disabling a source retains its credential.

断开账号会停止本地请求、清除凭据并中断此云盘的播放；禁用来源会保留凭据。
还需在微软账号权限页面或 Dropbox 设置的“应用”中移除 OpenPlayX，解除平台授权。

## Publisher setup / 开发者后台配置

Register apps owned by the publisher, rather than asking users to register.
Never supply a client secret to a native app. Public client IDs are build-time
values, not secrets; real account credentials must not be committed.

### OneDrive

1. Register a Microsoft identity public/native app supporting personal accounts.
2. Register the native redirect URI used by the build. The default is
   `com.openplayx.app://oauth/onedrive`.
3. Grant delegated `Files.Read` and `offline_access`. The adapter uses the
   `/consumers` authority and rejects drives whose `driveType` is not `personal`.
4. Set `ONEDRIVE_CLIENT_ID` when building. If the registered redirect differs,
   set `ONEDRIVE_REDIRECT_URI` and update native callback configuration together.

### Dropbox

1. Create a Scoped App; choose **Full Dropbox**, not App Folder.
2. Enable only `files.metadata.read` and `files.content.read`; allow public
   clients/PKCE. Request offline access to obtain a refresh token.
3. Register the exact redirect used by the build. The default is
   `com.openplayx.app://oauth/dropbox`. Validate the URI in the actual console
   and on each target platform before release. If registration requires a
   different URI, update the build setting and native handling together.
4. Set `DROPBOX_CLIENT_ID` (the app key); optionally `DROPBOX_REDIRECT_URI`.
   Complete Dropbox production approval before public rollout as required.

Example (replace placeholders with publisher public client IDs):

```sh
flutter build macos --debug \
  --dart-define=ONEDRIVE_CLIENT_ID=MICROSOFT_PUBLIC_CLIENT_ID \
  --dart-define=DROPBOX_CLIENT_ID=DROPBOX_APP_KEY
```

No configured client ID produces an explicit unavailable-in-this-build error.
It never falls back to a password/token or asks users for a developer secret.

### Platforms

- macOS/iOS use `ASWebAuthenticationSession`; Android uses the system browser
  auth flow. Android's callback activity handles `com.openplayx.app` and the
  Dart callback verifier additionally checks exact host/path, state, duplicate
  parameters and errors. iOS/macOS authentication sessions handle the custom
  callback scheme directly. No login embedded in the app is used.
- macOS already has Keychain access entitlements. iOS Runner now declares
  its Keychain group. Signing/provisioning must match `com.openplayx.app`.
- The project uses Android Gradle Plugin 9. The OAuth plugin is pinned to
  `flutter_web_auth_2 6.0.0-alpha.11`, which supports built-in Kotlin. This is
  a prerelease dependency and requires native platform regression before release.
- Native cloud sign-in is deliberately unavailable on Linux/Windows/Web in
  this first implementation. WebDAV retains its existing platform behavior.

## Storage, transport and limits

OAuth access/refresh tokens and new branded WebDAV app passwords are stored
using OS secure storage. SQLite's existing secret column contains an opaque,
random, instance-scoped reference for those sources. Configuration JSON and AI
source listings contain neither credentials nor signed content URLs. Existing
non-cloud source credentials keep their prior storage behavior. Secure writes
are staged before configuration commit; token rotation uses compare-and-set
against both the old reference and source revision. Configuration conflicts
remove the staged value. Local deletion removes the referenced credential.

OneDrive refs encode drive ID plus item ID. Dropbox refs use `id:` identities.
Names and paths are presentation/ancestry data, never media identity. Cloud
sources use only the selected root; per-path include/exclude policies of
path-addressed sources are not supported. API cursors translate to the host's
offset paging contract and can be reconstructed after restart. Cloud sources
do not advertise search or write capabilities.

Playback uses the controlled, loopback-only gateway. Each GET/HEAD obtains a
fresh temporary content link. Range is forwarded, including 64-bit offsets;
401/403/410 at a signed content URL triggers one renewed link attempt. API calls
never follow redirects with bearer authorization; content redirects receive
no bearer header. No video passes through an OpenPlayX public server.

Attachments use existing bounded NFO/image reads and adjacent artwork discovery,
with API metadata checks for filename, size and selected-root ancestry. Ancestor
NFO discovery follows provider parents for stable-ID sources. NFO-relative
nested image paths are not resolved as cloud paths; adjacent named artwork is
supported. Existing user-selected external subtitle files remain available.
Automatic discovery of cloud sibling subtitles is not implemented.

429 honors numeric or HTTP-date `Retry-After`, with bounded retries. A backoff
longer than the source timeout is returned to the caller without an early retry.
Disconnection cancels pending retries and closes provider clients. A broken
transfer or revoked account requires a user retry/re-authorization; uninterrupted
playback across arbitrary network changes is not claimed.

## Validation record / 验收记录

Automated checks use fake provider HTTP responses, in-memory OS storage, real
local gateway HTTP requests, and Flutter widget tests. They do **not** prove
real provider access, entitlement availability, real libVLC seek behavior, or
mobile callbacks.

| Source | macOS | Android | iOS |
|---|---|---|---|
| Jianguoyun | Preset/form + existing WebDAV regression; real account pending | Real account/device pending | Real account/device pending |
| 123 Cloud Drive | Empty endpoint/preset help + WebDAV regression; entitlement/account pending | Real account/device pending | Real account/device pending |
| OneDrive | Fake API/OAuth/Range tests; native app build passed; account/registration pending | Callback config implemented; build/device/account pending | Keychain/session config implemented; build/device/account pending |
| Dropbox | Fake API/OAuth/Range tests; native app build passed; account/registration pending | Callback config implemented; build/device/account pending | Keychain/session config implemented; build/device/account pending |

Completed automated checks on 2026-11-17:

```sh
flutter test test/data/sources test/features/sources test/metadata/metadata_test.dart --reporter expanded
# 117 tests passed (includes 13 cloud-specific tests).
flutter analyze --no-pub --no-fatal-infos
# No errors or warnings; existing informational/deprecation diagnostics remain.
flutter build macos --debug --no-pub
# Built OpenPlayX.app, including native OAuth and secure-storage plugins.
```

The cloud tests cover callback denial/invalid state, refresh merging and rotation,
late 401 responses, persistent shared sessions, revision conflicts, disconnection,
OS-storage reference isolation, multi-level library scanning and rename identity,
pagination/Unicode/large sizes, root boundaries, Retry-After cancellation,
HEAD/Range and signed-link renewal. The WebDAV regression also verifies that
neither its redirect probe nor playback sends credentials across origins.

Before release, execute the design's account matrix: add → restart → browse →
scan → play → seek; nested/paged/Unicode directories; >4 GB media; subtitles;
wrong passwords and denied folders; browser cancellation; bad callbacks;
expired/rotated/revoked tokens; multiple accounts; disconnect during requests;
offline recovery; 429; signed-link expiry and cross-origin authorization checks.
Record actual provider plan/limits and devices. No real account or OAuth
application ID was supplied for this implementation session.

## Official references

- [Jianguoyun WebDAV and app passwords](https://help.jianguoyun.com/?p=2064)
- [123 Cloud Drive console/site](https://www.123pan.com/)
- [Microsoft authorization code / PKCE](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- [Graph folder pagination](https://learn.microsoft.com/en-us/graph/api/driveitem-list-children?view=graph-rest-1.0)
- [Graph content download](https://learn.microsoft.com/en-us/graph/api/driveitem-get-content?view=graph-rest-1.0)
- [Dropbox OAuth and app permissions](https://docs.dropboxapi.com/dropbox-api/docs/oauth)
