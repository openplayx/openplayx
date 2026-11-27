# Television presentation

The TV presentation lives in the main Flutter application alongside desktop and
mobile. It shares the library/detail controllers, source resolution, playback
session, progress storage, subtitle/audio selection and playback backend. It
does not introduce device synchronization or a separate TV database schema.

## Device selection

`AppExperience.initialize()` runs before app startup. tvOS selects TV directly;
Android queries the runner's UI mode / Leanback feature over
`openplayx/device_experience`. Window width and an attached keyboard do not select
TV mode. `AppExperience(television: ..., child: ...)` allows isolated widget tests.

Preview the TV presentation with a normal development runner:

```sh
flutter run -d macos --dart-define=OPX_TV=true
```

TV uses the existing dark brand theme and an embedded player, including in this
desktop preview. Production tvOS builds continue to use the pinned FlutterTV
toolchain described in [tvos.md](../tvos.md).

## Views and focus

- `ui/tv/tv_action.dart`: one focus target per control, visible focus ring,
  single activation for Select / Enter / Space / gamepad A, and automatic
  scroll into view. Long-press repeat events never repeat activation.
- `app/app_navigation.dart`: labelled TV sidebar using existing destinations.
- `features/library/view/home_tv.dart`: featured real library item; shelves use
  larger artwork and captions. TV rows eagerly mount the bounded home shelf so
  off-screen tiles remain reachable by directional traversal. Stable item keys
  preserve focused tiles during reorder. Routes retain their scroll position.
- `features/library/view/media_detail_tv.dart`: remote-sized detail actions,
  season and episode selection, resource versions and loading feedback.
- `features/player/view/player_tv.dart`: remote controls and constrained audio,
  subtitle and speed panels. Desktop/mobile presentation files remain separate.

Navigation only activates on confirmation. Player arrows move focus; left/right
on the focused timeline preview a seek, confirmation commits, and Back cancels.
Other Back presses close a panel, hide controls, then exit playback. Android
system Back follows the same path. Panels exclude underlying controls from focus
and restore their originating control on close. Exiting playback restores the
detail/home control that launched it. Hidden tabs cannot receive focus.

## Validation and remaining acceptance

`test/features/tv_experience_test.dart` exercises repeat suppression, focus
restoration after route transitions, seek preview/cancel/commit, panel confinement,
the real in-memory library-to-player flow and Android system Back dispatch.
Existing navigation, source onboarding, media shelf and desktop/mobile player
tests cover shared-view regressions. These tests inject a playback backend.

Physical Apple TV / Android TV remotes, native playback, device UI-mode detection,
overscan and viewing-distance readability still require hardware acceptance.
Source forms and AI/settings pages currently reuse existing pages; TV-specific
onboarding, search, companion-device pairing and voice input are subsequent work.
